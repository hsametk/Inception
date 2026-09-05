COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE = docker compose -f $(COMPOSE_FILE)

-include srcs/.env

DATA_PATH ?= $(HOME)/data

.PHONY: all build up down stop start restart logs ps clean fclean re

all: up

build:
	$(COMPOSE) build

up:
	mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down --rmi all --remove-orphans

fclean: clean
	sudo rm -rf $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress

re: fclean all
