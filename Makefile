# One entry point for every dbt command. `make build` is the only thing you need to remember.
DBT := uv run dbt
FLAGS := --profiles-dir profiles

.PHONY: install deps build test docs show clean serve seed-full

install:
	uv sync
	$(DBT) deps $(FLAGS)

deps:
	$(DBT) deps $(FLAGS)

build:
	$(DBT) build $(FLAGS)

test:
	$(DBT) test $(FLAGS)

docs:
	$(DBT) docs generate $(FLAGS)

# Inspect a mart without leaving the terminal: make show MODEL=fct_daily_demand
show:
	$(DBT) show $(FLAGS) --select $(MODEL) --limit 20

serve:
	$(DBT) docs serve $(FLAGS)

clean:
	$(DBT) clean $(FLAGS)
