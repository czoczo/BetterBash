package main

import (
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync/atomic"
)

var (
	// requestCounter stores the number of HTTP requests (excluding /stats).
	requestCounter uint64
)

// colorComponentKeys defines the names for the color components in their encoding order.
// The encoding process described uses 9 components, but output is only for the first 8.
var colorComponentKeys = []string{
	"PRIMARY_COLOR",
	"SECONDARY_COLOR",
	"ROOT_COLOR",
	"TIME_COLOR",
	"ERR_COLOR",
	"SEPARATOR_COLOR",
	"BORDCOL",
	"PATH_COLOR",
	// The 9th component (C9, potentially "Reset") is decoded but not listed for output.
}

// decodeAndPrintColorsHandler processes requests with encoded color data.
func decodeAndPrintColorsHandler(w http.ResponseWriter, r *http.Request) {
	encodedData := strings.TrimPrefix(r.URL.Path, "/")

	// 1. Convert URL-safe Base64 characters back to standard Base64.
	// The Vue code replaces '+' with '-', '/' with '_', and removes padding.
	standardBase64 := strings.ReplaceAll(encodedData, "-", "+")
	standardBase64 = strings.ReplaceAll(standardBase64, "_", "/")

	// 2. Decode Base64 string to bytes.
	// RawStdEncoding handles Base64 without padding.
	// The Vue code generates an 8-character string from 6 bytes, which means no padding.
	decodedBytes, err := base64.RawStdEncoding.DecodeString(standardBase64)
	if err != nil {
		http.Error(w, fmt.Sprintf("Base64 decoding failed: %v. Input: '%s'", err, encodedData), http.StatusBadRequest)
		return
	}

	if len(decodedBytes) != 6 {
		http.Error(w, fmt.Sprintf("Decoded data must be 6 bytes long, got %d bytes from input '%s'", len(decodedBytes), encodedData), http.StatusBadRequest)
		return
	}

	// 3. Unpack 6 bytes into nine 5-bit values (C1 to C9).
	// Based on the Vue frontend's "Byte Packing" description:
	// Byte 1: C1_b4 C1_b3 C1_b2 C1_b1 C1_b0 C2_b4 C2_b3 C2_b2
	// Byte 2: C2_b1 C2_b0 C3_b4 C3_b3 C3_b2 C3_b1 C3_b0 C4_b4
	// Byte 3: C4_b3 C4_b2 C4_b1 C4_b0 C5_b4 C5_b3 C5_b2 C5_b1
	// Byte 4: C5_b0 C6_b4 C6_b3 C6_b2 C6_b1 C6_b0 C7_b4 C7_b3
	// Byte 5: C7_b2 C7_b1 C7_b0 C8_b4 C8_b3 C8_b2 C8_b1 C8_b0
	// Byte 6: C9_b4 C9_b3 C9_b2 C9_b1 C9_b0  0   0   0 (padding)
	fiveBitValues := make([]byte, 9)
	b := decodedBytes

	fiveBitValues[0] = b[0] >> 3                                     // C1
	fiveBitValues[1] = ((b[0] & 0x07) << 2) | (b[1] >> 6)             // C2
	fiveBitValues[2] = (b[1] & 0x3E) >> 1                             // C3
	fiveBitValues[3] = ((b[1] & 0x01) << 4) | (b[2] >> 4)             // C4
	fiveBitValues[4] = ((b[2] & 0x0F) << 1) | (b[3] >> 7)             // C5
	fiveBitValues[5] = (b[3] & 0x7C) >> 2                             // C6
	fiveBitValues[6] = ((b[3] & 0x03) << 3) | (b[4] >> 5)             // C7
	fiveBitValues[7] = b[4] & 0x1F                                     // C8
	fiveBitValues[8] = b[5] >> 3                                     // C9

	var result strings.Builder

	// 4. For each of the first 8 components, generate the bash color code.
	for i := 0; i < 8; i++ {
		val5bit := fiveBitValues[i]

		// Extract attributes from the 5-bit value:
		// (base_color_0_7 << 2) | (light_bit << 1) | bold_bit
		baseColor07 := (val5bit >> 2) & 0x07 // 3 MSB for base color (0-7)
		lightBit := (val5bit >> 1) & 0x01    // 1 bit for light state
		boldBit := val5bit & 0x01            // 1 bit for bold state

		// Convert to ANSI color codes
		baseAnsiCode := baseColor07 + 30 // Base colors are 30-37
		actualAnsiCode := baseAnsiCode
		if lightBit == 1 {
			actualAnsiCode += 60 // Bright colors are 90-97
		}

		styleAttr := 0 // Style: 0 for normal
		if boldBit == 1 {
			styleAttr = 1 // Style: 1 for bold
		}

		// Format as bash-compatible string: \[\033[<style>;<color>m\]
		bashColor := fmt.Sprintf(`\[\033[%d;%dm\]`, styleAttr, actualAnsiCode)
		result.WriteString(fmt.Sprintf("%s=%s\n", colorComponentKeys[i], bashColor))
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprint(w, result.String())
}

// statsReportHandler serves the HTTP request counter.
func statsReportHandler(w http.ResponseWriter, r *http.Request) {
	count := atomic.LoadUint64(&requestCounter)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%d", count)
}

// rootPathHandler handles requests to the bare "/" path.
func rootPathHandler(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Please provide an encoded string in the URL path, e.g., /YourEncodedString", http.StatusBadRequest)
}

// mainRouter is the primary HTTP handler.
// It routes requests to appropriate handlers and manages request counting.
func mainRouter(w http.ResponseWriter, r *http.Request) {
	// Handle /stats endpoint separately; it does not increment the counter.
	if r.URL.Path == "/stats" {
		statsReportHandler(w, r)
		return
	}

	// For all other paths, increment the request counter.
	atomic.AddUint64(&requestCounter, 1)

	// Handle the root path "/"
	if r.URL.Path == "/" {
		rootPathHandler(w, r)
	} else {
		// Assume any other path contains encoded data.
		decodeAndPrintColorsHandler(w, r)
	}
}

func main() {
	http.HandleFunc("/", mainRouter)

	port := "8080"
	log.Printf("🎨 Color Theme Backend starting on port %s (e.g., http://localhost:%s)\n", port, port)
	// Listen on all available network interfaces.
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ Failed to start server: %s\n", err)
	}
}
