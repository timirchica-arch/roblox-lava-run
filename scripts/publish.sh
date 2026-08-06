#!/usr/bin/env bash
# Отправляет собранный place.rbxlx в Roblox через Open Cloud.
# Ключ берётся из переменной окружения ROBLOX_API_KEY (секрет GitHub).

set -uo pipefail

FILE="place.rbxlx"
KEY="${ROBLOX_API_KEY:-}"
UNIVERSE="${UNIVERSE_ID:-0}"
PLACE="${PLACE_ID:-0}"
KIND="${VERSION_TYPE:-Published}"

if [ -z "$KEY" ]; then
	echo "ПРОПУСК: секрет ROBLOX_API_KEY не задан."
	echo "Добавь его в Settings -> Secrets and variables -> Actions -> New repository secret."
	exit 0
fi

if [ "$UNIVERSE" = "0" ] || [ "$PLACE" = "0" ]; then
	echo "ПРОПУСК: в place.json нет корректных universeId и placeId."
	exit 0
fi

if [ ! -f "$FILE" ]; then
	echo "ОШИБКА: файл $FILE не собран."
	exit 1
fi

# Адрес собирается из частей — так его точно никто не исказит.
SCHEME="https"
HOST="apis.roblox.com"
PATH_PART="/universes/v1/${UNIVERSE}/places/${PLACE}/versions"
QUERY="versionType=${KIND}"
URL="${SCHEME}://${HOST}${PATH_PART}?${QUERY}"

SIZE=$(wc -c < "$FILE" | tr -d ' ')
echo "Файл: ${FILE} (${SIZE} байт)"
echo "Опыт: universe ${UNIVERSE}, place ${PLACE}, режим ${KIND}"

CODE="000"
ATTEMPT=1
MAX=3

while [ "$ATTEMPT" -le "$MAX" ]; do
	echo "Попытка ${ATTEMPT} из ${MAX}..."
	CODE=$(curl -sS -o response.json -w "%{http_code}" -X POST "$URL" \
		-H "x-api-key: ${KEY}" \
		-H "Content-Type: application/xml" \
		--data-binary "@${FILE}")
	echo "Ответ Roblox: HTTP ${CODE}"
	case "$CODE" in
		200|201)
			break
			;;
		429|500|502|503|504)
			echo "Временная ошибка на стороне Roblox, жду и пробую снова."
			sleep $((ATTEMPT * 6))
			;;
		*)
			break
			;;
	esac
	ATTEMPT=$((ATTEMPT + 1))
done

BODY=""
if [ -f response.json ]; then
	BODY=$(head -c 600 response.json)
fi

case "$CODE" in
	200|201)
		echo "ГОТОВО: новая версия опубликована."
		echo "Ответ: ${BODY}"
		exit 0
		;;
	400)
		echo "ОШИБКА 400: Roblox не принял файл плейса (иногда это временный сбой — попробуй запустить ещё раз)."
		;;
	401)
		echo "ОШИБКА 401: ключ неверный или просрочен."
		;;
	403)
		echo "ОШИБКА 403: у ключа нет права Place Publishing -> Write на этот опыт."
		;;
	404)
		echo "ОШИБКА 404: не найден universe или place. Проверь числа в place.json."
		;;
	429)
		echo "ОШИБКА 429: слишком часто. Подожди минуту и запусти снова."
		;;
	000)
		echo "ОШИБКА сети: не удалось достучаться до Roblox."
		;;
	*)
		echo "ОШИБКА ${CODE}."
		;;
esac

echo "Ответ: ${BODY}"
exit 1
