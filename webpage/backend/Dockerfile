# Docker image definition

FROM golang:1.24-bookworm as go-build

WORKDIR /go/src/app

COPY ./*go .

RUN go mod init bbb

RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build -o /bbb .

# final image
FROM gcr.io/distroless/static-debian12:nonroot

USER nonroot:nonroot

WORKDIR /app

COPY --chown=nonroot:nonroot --from=go-build /bbb /app/

ENTRYPOINT ["./bbb"]
