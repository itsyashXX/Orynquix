.PHONY: install test lint typecheck check build

install:
	python -m pip install -e '.[dev]'

test:
	python -m pytest --cov=orynquix --cov-report=term-missing

lint:
	python -m ruff check .
	python -m ruff format --check .

typecheck:
	python -m mypy

check: lint typecheck test

build:
	python -m build

