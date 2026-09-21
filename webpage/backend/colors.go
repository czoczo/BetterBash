package main

import (
	"encoding/base64"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strings"
)

// randPathKeyword is an alternative to a theme code as the first URL segment.
// Every request to it is resolved to a freshly generated random theme, so
// /rand/getbb.sh installs a random theme and /rand/removebb.sh uninstalls it.
// It cannot clash with a theme code: those always encode to 8 characters.
const randPathKeyword = "rand"

var colorComponentKeys = []string{
	"PRIMARY_COLOR", "SECONDARY_COLOR", "ROOT_COLOR", "TIME_COLOR",
	"ERR_COLOR", "SEPARATOR_COLOR", "BORDCOL", "PATH_COLOR",
}

func decodeColorLogic(encodedData string) (map[string]string, string, bool, error) {
	standardBase64 := strings.ReplaceAll(encodedData, "-", "+")
	standardBase64 = strings.ReplaceAll(standardBase64, "_", "/")

	decodedBytes, err := base64.RawStdEncoding.DecodeString(standardBase64)
	if err != nil {
		return nil, "", false, fmt.Errorf("Base64 decoding failed: %v. Input: '%s'", err, encodedData)
	}

	if len(decodedBytes) != 6 {
		return nil, "", false, fmt.Errorf("Decoded data must be 6 bytes long, got %d bytes from input '%s'", len(decodedBytes), encodedData)
	}

	fiveBitValues := make([]byte, 9)
	b := decodedBytes
	fiveBitValues[0] = b[0] >> 3
	fiveBitValues[1] = ((b[0] & 0x07) << 2) | (b[1] >> 6)
	fiveBitValues[2] = (b[1] & 0x3E) >> 1
	fiveBitValues[3] = ((b[1] & 0x01) << 4) | (b[2] >> 4)
	fiveBitValues[4] = ((b[2] & 0x0F) << 1) | (b[3] >> 7)
	fiveBitValues[5] = (b[3] & 0x7C) >> 2
	fiveBitValues[6] = ((b[3] & 0x03) << 3) | (b[4] >> 5)
	fiveBitValues[7] = b[4] & 0x1F
	fiveBitValues[8] = b[5] >> 3

	// Extract avatar bit from the first bit of the 6th byte
	avatarEnabled := (b[5] & 0x80) != 0

	colorsMap := make(map[string]string)
	var resultList strings.Builder

	for i := 0; i < 8; i++ {
		val5bit := fiveBitValues[i]
		baseColor07 := (val5bit >> 2) & 0x07
		lightBit := (val5bit >> 1) & 0x01
		boldBit := val5bit & 0x01

		baseAnsiCode := baseColor07 + 30
		actualAnsiCode := baseAnsiCode
		if lightBit == 1 {
			actualAnsiCode += 60
		}
		styleAttr := 0
		if boldBit == 1 {
			styleAttr = 1
		}

		bashColor := fmt.Sprintf(`\[\033[%d;%dm\]`, styleAttr, actualAnsiCode)
		colorsMap[colorComponentKeys[i]] = bashColor
		// Ensure each definition is on a new line, directly usable in shell script
		resultList.WriteString(fmt.Sprintf("%s='%s'\n", colorComponentKeys[i], bashColor))
	}

	// Add the AVATAR variable
	avatarValue := "false"
	if avatarEnabled {
		avatarValue = "true"
	}
	resultList.WriteString(fmt.Sprintf("AVATAR='%s'\n", avatarValue))

	// Remove the last newline character from the block of definitions if present for cleaner insertion
	return colorsMap, strings.TrimSuffix(resultList.String(), "\n"), avatarEnabled, nil
}

// randomThemeCode builds a theme code carrying randomly picked colors and a
// random avatar flag, in exactly the format the WebUI generates (eight 5-bit
// color values plus the avatar bit packed into 6 bytes, then url-safe unpadded
// Base64), so it decodes identically in decodeColorLogic. Plain black is never
// picked, as it would be invisible on a dark terminal.
func randomThemeCode() string {
	fiveBitValues := make([]byte, len(colorComponentKeys))
	for i := range fiveBitValues {
		for {
			baseColor07 := byte(rand.Intn(8))
			lightBit := byte(rand.Intn(2))
			boldBit := byte(rand.Intn(2))
			if baseColor07 == 0 && lightBit == 0 {
				continue
			}
			fiveBitValues[i] = baseColor07<<2 | lightBit<<1 | boldBit
			break
		}
	}

	b := make([]byte, 6)
	b[0] = fiveBitValues[0]<<3 | fiveBitValues[1]>>2
	b[1] = (fiveBitValues[1]&0x03)<<6 | (fiveBitValues[2]<<1)&0x3F | fiveBitValues[3]>>4
	b[2] = (fiveBitValues[3]&0x0F)<<4 | fiveBitValues[4]>>1
	b[3] = (fiveBitValues[4]&0x01)<<7 | (fiveBitValues[5]<<2)&0x7C | fiveBitValues[6]>>3
	b[4] = (fiveBitValues[6]&0x07)<<5 | fiveBitValues[7]
	if rand.Intn(2) == 1 {
		b[5] = 0x80
	}

	return base64.RawURLEncoding.EncodeToString(b)
}

// resolveThemeSegment maps the "rand" keyword to a new random theme code. Any
// other segment (a real theme code) is passed through untouched, which keeps
// every previously generated URL working.
func resolveThemeSegment(encodedData string, r *http.Request) string {
	if encodedData != randPathKeyword {
		return encodedData
	}

	randomCode := randomThemeCode()
	log.Printf("🎲 %s resolved to randomly generated theme: %s", randPathKeyword, randomCode)
	recordMetrics(randPathKeyword, r.Method, "200")
	return randomCode
}
