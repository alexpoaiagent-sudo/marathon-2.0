#!/bin/bash

# 🔍 Скрипт ежедневной проверки Marathon 2.0
# Проверяет целостность, находит проблемы, генерирует отчёт

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║        🔍  Marathon 2.0 - Daily Health Check  🔍      ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Дата отчёта
REPORT_DATE=$(date '+%Y-%m-%d')
REPORT_FILE="reports/health-check-${REPORT_DATE}.md"

# Создаём папку для отчётов
mkdir -p reports

# Инициализация счётчиков
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
ERRORS=0

# Массивы для сообщений
declare -a ERROR_MESSAGES
declare -a WARNING_MESSAGES
declare -a INFO_MESSAGES

# Функция для проверки
check() {
    local name=$1
    local command=$2
    local error_msg=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        ERRORS=$((ERRORS + 1))
        ERROR_MESSAGES+=("$error_msg")
        return 1
    fi
}

# Функция для предупреждения
warn() {
    local name=$1
    local message=$2
    
    echo -e "${YELLOW}⚠${NC} $name"
    WARNINGS=$((WARNINGS + 1))
    WARNING_MESSAGES+=("$message")
}

# Функция для информации
info() {
    local message=$1
    echo -e "${BLUE}ℹ${NC} $message"
    INFO_MESSAGES+=("$message")
}

echo "📋 Проверка структуры..."
echo ""

# Проверка обязательных файлов
check "README.md существует" "test -f README.md" "Отсутствует главный README.md"
check "DICTIONARY.md существует" "test -f DICTIONARY.md" "Отсутствует словарь сущностей"
check "LICENSE существует" "test -f LICENSE" "Отсутствует файл лицензии"
check "CONTRIBUTING.md существует" "test -f CONTRIBUTING.md" "Отсутствует руководство по контрибуции"

# Проверка папок
check "Папка docs/ существует" "test -d docs" "Отсутствует папка с документацией"
check "Папка docs/meetings/ существует" "test -d docs/meetings" "Отсутствует папка со встречами"
check "Папка docs/templates/ существует" "test -d docs/templates" "Отсутствует папка с шаблонами"
check "Папка docs/examples/ существует" "test -d docs/examples" "Отсутствует папка с примерами"

# Проверка ключевых документов
check "questionnaire.md существует" "test -f docs/questionnaire.md" "Отсутствует опросник"
check "concepts.md существует" "test -f docs/concepts.md" "Отсутствует файл концепций"
check "minimal-practices.md существует" "test -f docs/minimal-practices.md" "Отсутствует описание практик"

# Проверка всех встреч
for i in {1..4}; do
    meeting_file="docs/meetings/meeting-0${i}.md"
    check "Встреча $i существует" "test -f $meeting_file" "Отсутствует описание встречи $i"
done

echo ""
echo "🔗 Проверка ссылок..."
echo ""

# Функция проверки битых ссылок
check_links() {
    local broken_links=0
    
    # Находим все .md файлы
    while IFS= read -r file; do
        # Ищем все markdown ссылки вида [text](link.md)
        while IFS= read -r link; do
            # Извлекаем путь к файлу
            target=$(echo "$link" | sed -E 's/.*\(([^)]+)\).*/\1/')
            
            # Пропускаем внешние ссылки
            if [[ $target == http* ]] || [[ $target == #* ]]; then
                continue
            fi
            
            # Получаем директорию текущего файла
            dir=$(dirname "$file")
            
            # Формируем полный путь
            full_path="$dir/$target"
            
            # Проверяем существование
            if [[ ! -f $full_path ]]; then
                warn "Битая ссылка в $file" "Ссылка на несуществующий файл: $target"
                broken_links=$((broken_links + 1))
            fi
        done < <(grep -o '\[.*\]([^)]*)' "$file" 2>/dev/null || true)
    done < <(find . -name "*.md" -type f)
    
    if [ $broken_links -eq 0 ]; then
        info "Все внутренние ссылки работают"
    fi
}

check_links

echo ""
echo "📊 Проверка консистентности..."
echo ""

# Проверка упоминания всех состояний
check_states() {
    local states=("Хаос" "Застой" "Точка поворота")
    local found_all=true
    
    for state in "${states[@]}"; do
        if ! grep -r "$state" docs/ &> /dev/null; then
            warn "Состояние не упоминается" "Состояние '$state' не найдено в документации"
            found_all=false
        fi
    done
    
    if $found_all; then
        info "Все три состояния упомянуты в документации"
    fi
}

check_states

# Проверка упоминания всех практик
check_practices() {
    local practices=("слот" "мимолётная заметка" "трекер" "рабочий продукт" "ИИ-помощник" "стоп-момент")
    local found=0
    
    for practice in "${practices[@]}"; do
        if grep -r "$practice" docs/minimal-practices.md &> /dev/null; then
            found=$((found + 1))
        fi
    done
    
    if [ $found -eq 6 ]; then
        info "Все 6 практик описаны в minimal-practices.md"
    else
        warn "Неполное описание практик" "Найдено только $found из 6 практик"
    fi
}

check_practices

echo ""
echo "📈 Статистика репозитория..."
echo ""

# Подсчёт файлов
total_files=$(find . -name "*.md" -type f | wc -l)
doc_files=$(find docs/ -name "*.md" -type f 2>/dev/null | wc -l || echo 0)
example_files=$(find docs/examples/ -name "*.md" -type f 2>/dev/null | wc -l || echo 0)

info "Всего Markdown файлов: $total_files"
info "Файлов документации: $doc_files"
info "Файлов с примерами: $example_files"

# Подсчёт строк
total_lines=$(find . -name "*.md" -type f -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
info "Всего строк в документации: $total_lines"

# Проверка изменений за последний день (если это Git репозиторий)
if [ -d .git ]; then
    echo ""
    echo "🔄 Изменения за последние 24 часа..."
    echo ""
    
    # Коммиты
    commits_count=$(git log --since="24 hours ago" --oneline 2>/dev/null | wc -l || echo 0)
    
    if [ $commits_count -gt 0 ]; then
        info "Коммитов за 24 часа: $commits_count"
        
        # Показываем последние коммиты
        echo ""
        echo "Последние изменения:"
        git log --since="24 hours ago" --pretty=format:"  • %s (%ar)" --abbrev-commit 2>/dev/null || echo "  Нет данных"
        echo ""
    else
        info "Изменений за последние 24 часа не было"
    fi
    
    # Изменённые файлы
    echo ""
    changed_files=$(git diff --name-only HEAD~1 2>/dev/null | wc -l || echo 0)
    if [ $changed_files -gt 0 ]; then
        info "Изменённых файлов в последнем коммите: $changed_files"
        git diff --name-only HEAD~1 2>/dev/null | while read file; do
            echo "    • $file"
        done
    fi
    
    # Статистика изменений
    echo ""
    stats=$(git diff --stat HEAD~1 2>/dev/null | tail -1 || echo "")
    if [ ! -z "$stats" ]; then
        info "Статистика: $stats"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Итоговый результат
echo "📊 ИТОГОВЫЙ РЕЗУЛЬТАТ"
echo ""
echo "✓ Успешных проверок: $PASSED_CHECKS/$TOTAL_CHECKS"
echo "⚠ Предупреждений: $WARNINGS"
echo "✗ Ошибок: $ERRORS"
echo ""

# Определяем общий статус
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 Репозиторий в отличном состоянии!${NC}"
    STATUS="🟢 ОТЛИЧНО"
elif [ $ERRORS -eq 0 ] && [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Репозиторий в хорошем состоянии, но есть предупреждения${NC}"
    STATUS="🟡 ХОРОШО"
else
    echo -e "${RED}❌ Найдены критические проблемы, требуется внимание${NC}"
    STATUS="🔴 ТРЕБУЕТ ВНИМАНИЯ"
fi

echo ""

# Генерируем Markdown отчёт
echo "📝 Генерация отчёта..."

cat > "$REPORT_FILE" << 'ENDREPORT'
# 🔍 Отчёт о проверке Marathon 2.0

**Дата:** REPORT_DATE_PLACEHOLDER  
**Статус:** STATUS_PLACEHOLDER

---

## 📊 Общая статистика

- **Проверок выполнено:** TOTAL_CHECKS_PLACEHOLDER
- **Успешно:** PASSED_CHECKS_PLACEHOLDER
- **Предупреждений:** WARNINGS_PLACEHOLDER
- **Ошибок:** ERRORS_PLACEHOLDER

---

## 📈 Статистика репозитория

- **Всего Markdown файлов:** TOTAL_FILES_PLACEHOLDER
- **Файлов документации:** DOC_FILES_PLACEHOLDER
- **Файлов с примерами:** EXAMPLE_FILES_PLACEHOLDER
- **Всего строк:** TOTAL_LINES_PLACEHOLDER

ENDREPORT

# Подставляем значения
sed -i "s/REPORT_DATE_PLACEHOLDER/$REPORT_DATE/g" "$REPORT_FILE"
sed -i "s/STATUS_PLACEHOLDER/$STATUS/g" "$REPORT_FILE"
sed -i "s/TOTAL_CHECKS_PLACEHOLDER/$TOTAL_CHECKS/g" "$REPORT_FILE"
sed -i "s/PASSED_CHECKS_PLACEHOLDER/$PASSED_CHECKS/g" "$REPORT_FILE"
sed -i "s/WARNINGS_PLACEHOLDER/$WARNINGS/g" "$REPORT_FILE"
sed -i "s/ERRORS_PLACEHOLDER/$ERRORS/g" "$REPORT_FILE"
sed -i "s/TOTAL_FILES_PLACEHOLDER/$total_files/g" "$REPORT_FILE"
sed -i "s/DOC_FILES_PLACEHOLDER/$doc_files/g" "$REPORT_FILE"
sed -i "s/EXAMPLE_FILES_PLACEHOLDER/$example_files/g" "$REPORT_FILE"
sed -i "s/TOTAL_LINES_PLACEHOLDER/$total_lines/g" "$REPORT_FILE"

# Добавляем изменения за 24 часа (если есть Git)
if [ -d .git ] && [ $commits_count -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF

---

## 🔄 Изменения за последние 24 часа

**Коммитов:** $commits_count

### Последние коммиты:

EOF
    git log --since="24 hours ago" --pretty=format:"- %s (%ar, %an)" --abbrev-commit 2>/dev/null >> "$REPORT_FILE" || true
    echo "" >> "$REPORT_FILE"
    
    if [ $changed_files -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF

### Изменённые файлы:

EOF
        git diff --name-only HEAD~1 2>/dev/null | while read file; do
            echo "- \`$file\`" >> "$REPORT_FILE"
        done
    fi
fi

# Добавляем ошибки
if [ $ERRORS -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF

---

## ❌ Найденные ошибки

EOF
    for error in "${ERROR_MESSAGES[@]}"; do
        echo "- ❌ $error" >> "$REPORT_FILE"
    done
fi

# Добавляем предупреждения
if [ $WARNINGS -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF

---

## ⚠️ Предупреждения

EOF
    for warning in "${WARNING_MESSAGES[@]}"; do
        echo "- ⚠️ $warning" >> "$REPORT_FILE"
    done
fi

# Добавляем информационные сообщения
if [ ${#INFO_MESSAGES[@]} -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF

---

## ℹ️ Дополнительная информация

EOF
    for info in "${INFO_MESSAGES[@]}"; do
        echo "- ℹ️ $info" >> "$REPORT_FILE"
    done
fi

# Рекомендации
cat >> "$REPORT_FILE" << EOF

---

## 💡 Рекомендации

EOF

if [ $ERRORS -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF
- 🔴 **Критично:** Исправьте найденные ошибки как можно скорее
- Проверьте целостность структуры репозитория
- Убедитесь, что все обязательные файлы на месте
EOF
elif [ $WARNINGS -gt 0 ]; then
    cat >> "$REPORT_FILE" << EOF
- 🟡 Обратите внимание на предупреждения
- Проверьте битые ссылки и исправьте их
- Убедитесь в консистентности терминологии
EOF
else
    cat >> "$REPORT_FILE" << EOF
- 🟢 Репозиторий в отличном состоянии!
- Продолжайте поддерживать качество документации
- Регулярно проверяйте новые изменения
EOF
fi

# Футер отчёта
cat >> "$REPORT_FILE" << EOF

---

**Отчёт сгенерирован:** $(date '+%Y-%m-%d %H:%M:%S')  
**Скрипт:** check-integrity.sh v1.0
EOF

echo -e "${GREEN}✓${NC} Отчёт сохранён: $REPORT_FILE"
echo ""

# Возвращаем код выхода
if [ $ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
