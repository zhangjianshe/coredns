# ------------------------------------
# STAGE 1: BUILDER
# Fix: Uses Go 1.24+ to satisfy CoreDNS dependency requirements
# ------------------------------------
FROM golang:1.24-alpine AS builder

# Proxy Configuration (Uncomment and set if behind a network proxy)
# ENV HTTP_PROXY="http://192.168.1.139:7890"
# ENV HTTPS_PROXY="http://192.168.1.139:7890"

# Set the CoreDNS source directory
WORKDIR /go/src/coredns
RUN apk add --no-cache git

# Clone CoreDNS source code
RUN git clone https://github.com/coredns/coredns .

# Add the 'api' plugin to the list of plugins to be built
RUN sed -i '/^.*forward/i api:github.com/coredns/coredns/plugin/api' plugin.cfg

RUN go get github.com/coredns/coredns/plugin/api
RUN go mod tidy
# CRITICAL FIX: Explicitly fetch the 'api' plugin module dependency 
# before running generate/build. This resolves the "no required module provides package..." error.

# Build CoreDNS binary
RUN go generate
RUN go build -o /usr/local/bin/coredns

# ------------------------------------
# STAGE 2: FINAL IMAGE
# Creates a minimal runtime environment
# ------------------------------------
FROM alpine:3.20
RUN apk add --no-cache ca-certificates

# Create the non-root user for security
RUN addgroup -S coredns && adduser -S coredns -G coredns

# Copy the compiled binary from the builder stage
COPY --from=builder /usr/local/bin/coredns /usr/local/bin/coredns

# Set permissions and user
WORKDIR /
USER coredns

# Expose ports: 53 for DNS (UDP/TCP), 8080 for ExternalDNS API (TCP)
EXPOSE 53/udp 53/tcp 8080/tcp

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/coredns"]

