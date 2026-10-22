#!/usr/bin/env bash
# Выполняет все запросы из queries/ и собирает отчёт в Markdown: описание запроса, время и таблица.
# Подключение берётся из стандартных переменных PGHOST, PGUSER, PGDATABASE, PGPASSWORD.
# Использование: scripts/report.sh > REPORT.md
set -euo pipefail
cd "$(dirname "$0")/.."

echo "# Отчёт онлайн-кинотеатра за 2025 год"
echo
echo "Сгенерировано $(date -u '+%Y-%m-%d %H:%M UTC') на $(psql -XAtc 'select version()' | cut -d, -f1)."
echo
for f in queries/*.sql; do
  title=$(head -1 "$f" | sed 's/^-- //')
  echo "## $(basename "$f" .sql): $title"
  echo
  sed -n '2p' "$f" | sed 's/^-- /_/; s/$/_/'
  echo
  start=$(date +%s%N)
  # \pset format aligned внутри блока кода читается лучше markdown-таблицы при длинных числах
  echo '```'
  psql -X -v ON_ERROR_STOP=1 --pset footer=off -f "$f"
  echo '```'
  end=$(date +%s%N)
  echo
  echo "Время: $(( (end - start) / 1000000 )) мс"
  echo
done
