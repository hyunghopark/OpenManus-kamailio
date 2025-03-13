.PHONY: setup dev prod clean logs

setup:
	@echo "Setting up development environment..."
	@chmod +x scripts/deploy/setup.sh
	@./scripts/deploy/setup.sh

dev:
	@echo "Starting development environment..."
	@docker-compose -f docker/dev/docker-compose.yml up --build

prod:
	@echo "Starting production environment..."
	@docker-compose -f docker/prod/docker-compose.yml up -d --build

clean:
	@echo "Cleaning up..."
	@docker-compose -f docker/dev/docker-compose.yml down -v
	@docker-compose -f docker/prod/docker-compose.yml down -v
	@rm -rf logs/*

logs:
	@docker-compose -f docker/dev/docker-compose.yml logs -f

.DEFAULT_GOAL := dev 