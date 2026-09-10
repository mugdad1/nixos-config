#!/usr/bin/env bash
set -euo pipefail

source "${HOME}/.config/nixos-config/.secrets" 2>/dev/null || true

NOTION_VERSION="2022-06-28"
BASE_URL="https://api.notion.com/v1"

_notion_curl() {
  local method="$1" endpoint="$2"
  shift 2
  curl -s -X "$method" "$BASE_URL$endpoint" \
    -H "Authorization: Bearer $NOTION_API_KEY" \
    -H "Notion-Version: $NOTION_VERSION" \
    -H "Content-Type: application/json" \
    "$@"
}

case "${1:-help}" in
  whoami)
    _notion_curl GET /users/me | jq .
    ;;
  search)
    shift
    query="${1:-}"
    _notion_curl POST /search -d "{\"query\": \"$query\"}" | jq '.results[] | {id, object, title: (.properties.title.title[0].text.content // .title[0].text.content // "untitled")}'
    ;;
  pages)
    shift
    _notion_curl GET "/pages/$1" | jq .
    ;;
  blocks)
    shift
    _notion_curl GET "/blocks/$1/children?page_size=100" | jq .
    ;;
  create-page)
    shift
    parent_id="${1:?Usage: notion create-page <parent-id> <title>}"
    title="${2:-Untitled}"
    _notion_curl POST /pages -d "{
      \"parent\": { \"page_id\": \"$parent_id\" },
      \"properties\": {
        \"title\": { \"title\": [{ \"text\": { \"content\": \"$title\" } }] }
      }
    }" | jq '{id, url}'
    ;;
  create-db)
    shift
    parent_id="${1:?Usage: notion create-db <parent-id> <title>}"
    title="${2:-Database}"
    _notion_curl POST /databases -d "{
      \"parent\": { \"page_id\": \"$parent_id\" },
      \"title\": [{ \"text\": { \"content\": \"$title\" } }],
      \"properties\": {
        \"Name\": { \"title\": {} },
        \"Status\": { \"status\": {} },
        \"Priority\": { \"select\": { \"options\": [
          { \"name\": \"High\", \"color\": \"red\" },
          { \"name\": \"Medium\", \"color\": \"yellow\" },
          { \"name\": \"Low\", \"color\": \"green\" }
        ]}},
        \"Due\": { \"date\": {} },
        \"Assignee\": { \"people\": {} },
        \"Tags\": { \"multi_select\": { \"options\": [] } }
      }
    }" | jq '{id, title}'
    ;;
  query-db)
    shift
    db_id="${1:?Usage: notion query-db <db-id>}"
    _notion_curl POST "/databases/$db_id/query" -d '{}' | jq '.results[] | {id, name: .properties.Name.title[0].plain_text, status: .properties.Status.status.name}'
    ;;
  add-task)
    shift
    db_id="${1:?Usage: notion add-task <db-id> <name> [status] [priority] [due]}"
    name="${2:?Missing task name}"
    status="${3:-Not started}"
    priority="${4:-Medium}"
    due="${5:-}"
    props="\"Name\": {\"title\": [{\"text\": {\"content\": \"$name\"}}]}, \"Status\": {\"status\": {\"name\": \"$status\"}}, \"Priority\": {\"select\": {\"name\": \"$priority\"}}"
    [ -n "$due" ] && props="$props, \"Due\": {\"date\": {\"start\": \"$due\"}}"
    _notion_curl POST /pages -d "{
      \"parent\": { \"database_id\": \"$db_id\" },
      \"properties\": { $props }
    }" | jq '{id, name: .properties.Name.title[0].plain_text, status: .properties.Status.status.name}'
    ;;
  update-task)
    shift
    page_id="${1:?Usage: notion update-task <page-id> [status]}"
    status="${2:-}"
    props=""
    [ -n "$status" ] && props="\"Status\": {\"status\": {\"name\": \"$status\"}}"
    _notion_curl PATCH "/pages/$page_id" -d "{ \"properties\": { $props } }" | jq '{id, status: .properties.Status.status.name}'
    ;;
  add-block)
    shift
    block_id="${1:?Usage: notion add-block <block-id> [type] [content]}"
    type="${2:-paragraph}"
    content="${3:-}"
    _notion_curl PATCH "/blocks/$block_id/children" -d "{
      \"children\": [{
        \"type\": \"$type\",
        \"$type\": { \"rich_text\": [{ \"text\": { \"content\": \"$content\" } }] }
      }]
    }" | jq '.results[0].id'
    ;;
  add-heading)
    shift
    block_id="${1:?Usage: notion add-heading <block-id> <level> <content>}"
    level="${2:-2}"
    content="${3:-}"
    _notion_curl PATCH "/blocks/$block_id/children" -d "{
      \"children\": [{
        \"type\": \"heading_$level\",
        \"heading_$level\": { \"rich_text\": [{ \"text\": { \"content\": \"$content\" } }] }
      }]
    }" | jq '.results[0].id'
    ;;
  add-todo)
    shift
    block_id="${1:?Usage: notion add-todo <block-id> <text> [checked]}"
    text="${2:?Missing text}"
    checked="${3:-false}"
    _notion_curl PATCH "/blocks/$block_id/children" -d "{
      \"children\": [{
        \"type\": \"to_do\",
        \"to_do\": { \"rich_text\": [{ \"text\": { \"content\": \"$text\" } }], \"checked\": $checked }
      }]
    }" | jq '.results[0].id'
    ;;
  add-divider)
    shift
    block_id="${1:?Usage: notion add-divider <block-id>}"
    _notion_curl PATCH "/blocks/$block_id/children" -d '{
      "children": [{ "type": "divider", "divider": {} }]
    }' | jq '.results[0].id'
    ;;
  db-schema)
    shift
    db_id="${1:?Usage: notion db-schema <db-id>}"
    _notion_curl GET "/databases/$db_id" | jq '{id, title, properties}'
    ;;
  help|*)
    cat <<'EOF'
Notion CLI — Usage: notion <command> [args...]

  whoami                      Show bot user info
  search <query>              Search workspace
  pages <page-id>             Get page details
  blocks <block-id>           List block children

  create-page <parent-id> <title>         Create a sub-page
  create-db <parent-id> <title>           Create a task database

  db-schema <db-id>           Show database schema
  query-db <db-id>            List all items in database

  add-task <db-id> <name> [status] [priority] [due-date]
  update-task <page-id> [status]
                               Statuses: Not started, In progress, Done

  add-block <id> [type] [content]          Add paragraph
  add-heading <id> [level] [content]       Add heading (1-3)
  add-todo <id> <text> [checked]           Add checkbox
  add-divider <id>                         Add horizontal rule

Environment:
  NOTION_API_KEY    Set in ~/.config/nixos-config/.secrets
EOF
    ;;
esac
