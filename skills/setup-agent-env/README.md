# setup-agent-env

Скилл уровня пользователя: разворачивает окружение агента Claude Code — agent-lsp с
языковыми серверами, хуки agent-lsp, jarpeek, PostgreSQL MCP с профилями БД, запреты в
`settings.json`. Подключается ссылкой в `~/.claude/skills`.

## Новый компьютер

1. Вручную: Homebrew (https://brew.sh), Claude Code CLI и вход в аккаунт, Docker Desktop.
2. Перенести секреты проектов (`~/.config/<проект>/*.env`) — в репозитории их нет.
3. Подключить скилл и развернуть окружение:

```bash
git clone https://github.com/Tron-0-0/beta-cli-skils.git ~/Personal/Playground/beta-cli-skils
mkdir -p ~/.claude/skills
ln -s ~/Personal/Playground/beta-cli-skils/skills/setup-agent-env ~/.claude/skills/setup-agent-env
~/.claude/skills/setup-agent-env/scripts/setup.sh apply
```

4. Запустить Claude Code и попросить: «проверь окружение агента» — скилл создаст профили БД
   и проверит все серверы вживую.
