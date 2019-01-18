#!/bin/bash
#
# [English]
#
# Author: Ivan Ivanovich Tatarinov, 2018, 2019, <ivan-tat@ya.ru>
#
# This is free and unencumbered software released into the public domain.
# For more information, please refer to <http://unlicense.org>
#
# [Русский]
#
# Автор: Иван Иванович Татаринов, 2018, 2019, <ivan-tat@ya.ru>
#
# Это свободное и необременённое программное обеспечение, переданное в общественное достояние.
# За дополнительной информацией обратитесь на сайт <http://unlicense.org>
#

# Used tools:
#   GNU coreutils, bash, [dialog | whiptail], youtube-dl.

set -e

TMPFILE=tmp
VIDLIST_ALL='video-all.txt'
VIDLIST_NEW='video-new.txt'
VIDLIST_START='1'
OUTDIR='video'

declare DIALOG
declare -i DIALOG_CLEAR
declare -A DESC
declare CHOICE
declare -i ind

_msg() {
    echo "$1" >&2
}

DIALOG=`which dialog 2>/dev/null || true`
DIALOG_CLEAR=1

if [[ -z "$DIALOG" ]]; then
    DIALOG=`which whiptail 2>/dev/null || true`
    DIALOG_CLEAR=0
fi

DESC[all]='все видео'
DESC[new]='новое видео'

if [[ -z "$DIALOG" ]]; then
    select CHOICE in "${DESC[all]}" "${DESC[new]}" "выход"; do
        case "$REPLY" in
        1)
            CHOICE=all
            break
            ;;
        2)
            CHOICE=new
            break
            ;;
        3)
            exit 1
        esac
    done
else
    "$DIALOG" --backtitle \
    'Простое скачивание перечня видео-файлов с сервиса YouTube' \
    --title \
    'Выбор' \
    --notags --menu \
    'Выберите перечень видео для скачивания:' \
    10 50 2 \
    all \
    "${DESC[all]}" \
    new \
    "${DESC[new]}" \
    2>"$TMPFILE" || { rm -f "$TMPFILE"; exit 1; }
    read CHOICE < "$TMPFILE" || true
    rm -f "$TMPFILE"
    if [[ $DIALOG_CLEAR -ne 0 ]]; then clear; fi
fi

echo 'Выбран перечень: '${DESC[$CHOICE]}

case "$CHOICE" in
all)
    VIDLIST="$VIDLIST_ALL"
    ind=$((VIDLIST_START))
    ;;
new)
    VIDLISTOLD="$VIDLIST_ALL"
    VIDLIST="$VIDLIST_NEW"
    ind=`wc -l<"$VIDLISTOLD"`
    ind=$((ind+1))
    ;;
*)
    exit 1
esac

if [[ x`wc -l<"$VIDLIST"` == 'x0' ]]; then
    _msg 'Нечего скачивать.'
    exit
fi

_msg 'Поехали...'

mkdir -p "$OUTDIR"

while read L; do
    if [[ x"${L:0:1}" != 'x#' ]]; then
        VIDEO_ID="${L%%|*}"
        VIDEO_URL='https://www.youtube.com/watch?v='"$VIDEO_ID"
        L="${L#*|}"
        VIDEO_FORMAT_SELECT="${L%%|*}"
        L="${L#*|}"
        VIDEO_TITLE="${L%%|*}"
        FILE_NAME="${L#*|}"
        FILE_INDEX=`printf "%03d" $ind`
        _msg 'Загрузка видео:'
        _msg "  Номер файла: $FILE_INDEX"
        _msg "  Код видео: $VIDEO_ID"
        _msg "  Ссылка: $VIDEO_URL"
        _msg "  Формат видео: $VIDEO_FORMAT_SELECT"
        _msg "  Заголовок: $VIDEO_TITLE"
        _msg "  Имя файла: $FILE_NAME"
        youtube-dl --dump-json "$VIDEO_URL" >"$TMPFILE"
        VIDEO_UPLOAD_DATE=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$TMPFILE" --get-filename -o "%(upload_date)s" "$VIDEO_URL"`
        VIDEO_EXT=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$TMPFILE" --get-filename -o "%(ext)s" "$VIDEO_URL"`
        VIDEO_UPLOAD_DATE="${VIDEO_UPLOAD_DATE:0:4}-${VIDEO_UPLOAD_DATE:4:2}-${VIDEO_UPLOAD_DATE:6:2}"
        VIDEO_OUTPUT="$OUTDIR/$FILE_INDEX-$VIDEO_UPLOAD_DATE. $FILE_NAME"
        VIDEO_TMPDESC="$VIDEO_OUTPUT.description"
        VIDEO_COMMENT="$VIDEO_OUTPUT.txt"
        if [[ ! -f "$VIDEO_COMMENT" ]]; then
            youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$TMPFILE" --write-description --write-thumbnail -o "$VIDEO_OUTPUT.%(ext)s" "$VIDEO_URL"
            cat >"$TMPFILE" <<EOT
$VIDEO_TITLE

Ссылка на видео: $VIDEO_URL
Опубликовано: $VIDEO_UPLOAD_DATE

EOT
            cat "$TMPFILE" "$VIDEO_TMPDESC" >"$VIDEO_COMMENT"
            rm "$VIDEO_TMPDESC"
        fi
    fi
    ind=$((ind+1))
done <"$VIDLIST"

case "$CHOICE" in
all)
    ;;
new)
    _msg 'Обновление списка видео...'
    cat "$VIDLIST" >> "$VIDLISTOLD"
    truncate -s 0 "$VIDLIST"
    ;;
*)
    exit 1
esac

rm "$TMPFILE"
_msg 'Задание успешно завершено.'
