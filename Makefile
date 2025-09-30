.PHONY: build up down shell clean flash monitor help

# Default target
help:
	@echo "ESP32 Docker Development Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  build   - Build the Docker image"
	@echo "  up      - Start the development container in background"
	@echo "  down    - Stop and remove the container"
	@echo "  shell   - Open a shell in the container"
	@echo "  clean   - Remove Docker images and volumes"
	@echo "  flash   - Flash the ESP32 (requires PORT variable)"
	@echo "  monitor - Monitor ESP32 serial output (requires PORT variable)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make shell"
	@echo "  make flash PORT=/dev/ttyUSB0"
	@echo "  make monitor PORT=/dev/ttyUSB0"

# Build the Docker image
build:
	docker-compose build

# Start container in background
up:
	docker-compose up -d

# Stop container
down:
	docker-compose down

# Open a shell in the container
shell:
	docker-compose run --rm esp32-dev /bin/bash

# Clean up Docker resources
clean:
	docker-compose down -v
	docker rmi esp32-dev:latest 2>/dev/null || true

# Flash the ESP32
flash:
	@if [ -z "$(PORT)" ]; then \
		echo "Error: PORT variable is required. Example: make flash PORT=/dev/ttyUSB0"; \
		exit 1; \
	fi
	docker-compose run --rm esp32-dev bash -c "cd /project && idf.py -p $(PORT) flash"

# Monitor serial output
monitor:
	@if [ -z "$(PORT)" ]; then \
		echo "Error: PORT variable is required. Example: make monitor PORT=/dev/ttyUSB0"; \
		exit 1; \
	fi
	docker-compose run --rm esp32-dev bash -c "cd /project && idf.py -p $(PORT) monitor"
