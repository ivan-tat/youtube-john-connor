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

BACKTITLE='Простое скачивание перечня видео-файлов с сервиса YouTube'

TMPFILE=tmp
VIDLIST_ALL='video-all.txt'
VIDLIST_NEW='video-new.txt'
VIDLIST_START='1'
OUTDIR='video'
YTDIR="$OUTDIR"'/youtube'

declare DIALOG
declare -i DIALOG_CLEAR
declare -A DESC
declare OPT_VIDLIST
declare OPT_UPDATE
declare OPT_LINKTYPE
declare -i ind

_msg() {
    echo "$1" >&2
}

_select_list() {
if [[ -z "$DIALOG" ]]; then
    select OPT_VIDLIST in "${DESC[all]}" "${DESC[new]}" "выход"; do
        case "$REPLY" in
        1)
            OPT_VIDLIST=all
            break
            ;;
        2)
            OPT_VIDLIST=new
            break
            ;;
        3)
            exit 1
        esac
    done
else
    "$DIALOG" --backtitle "$BACKTITLE" \
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
    read OPT_VIDLIST < "$TMPFILE" || true
    rm -f "$TMPFILE"
    if [[ $DIALOG_CLEAR -ne 0 ]]; then clear; fi
fi
}

_select_update() {
if [[ -z "$DIALOG" ]]; then
    select OPT_UPDATE in "${DESC[each_line]}" "${DESC[in_the_end]}" "выход"; do
        case "$REPLY" in
        1)
            OPT_UPDATE=each_line
            break
            ;;
        2)
            OPT_UPDATE=in_the_end
            break
            ;;
        3)
            exit 1
        esac
    done
else
    "$DIALOG" --backtitle "$BACKTITLE" \
    --title \
    'Выбор' \
    --notags --menu \
    'Выберите способ обновления перечня видео при скачивании:' \
    10 50 2 \
    each_line \
    "${DESC[each_line]}" \
    in_the_end \
    "${DESC[in_the_end]}" \
    2>"$TMPFILE" || { rm -f "$TMPFILE"; exit 1; }
    read OPT_UPDATE < "$TMPFILE" || true
    rm -f "$TMPFILE"
    if [[ $DIALOG_CLEAR -ne 0 ]]; then clear; fi
fi
}

_select_link_type() {
    if [[ -z "$DIALOG" ]]; then
        select OPT_LINKTYPE in "${DESC[sym_link_rel]}" "${DESC[sym_link_abs]}" "${DESC[hard_link]}" "выход"; do
            case "$REPLY" in
            1)
                OPT_LINKTYPE=sym_link_rel
                break
                ;;
            2)
                OPT_LINKTYPE=sym_link_abs
                break
                ;;
            3)
                OPT_LINKTYPE=hard_link
                break
                ;;
            4)
                exit 1
            esac
        done
    else
        "$DIALOG" --backtitle "$BACKTITLE" \
        --title \
        'Выбор' \
        --notags --menu \
        'Выберите тип ссылки при создании конечного видео-файла:' \
        11 50 3 \
        sym_link_rel \
        "${DESC[sym_link_rel]}" \
        sym_link_abs \
        "${DESC[sym_link_abs]}" \
        hard_link \
        "${DESC[hard_link]}" \
        2>"$TMPFILE" || { rm -f "$TMPFILE"; exit 1; }
        read OPT_LINKTYPE < "$TMPFILE" || true
        rm -f "$TMPFILE"
        if [[ $DIALOG_CLEAR -ne 0 ]]; then clear; fi
    fi
}

DIALOG=`which dialog 2>/dev/null || true`
DIALOG_CLEAR=1

if [[ -z "$DIALOG" ]]; then
    DIALOG=`which whiptail 2>/dev/null || true`
    DIALOG_CLEAR=0
fi

DESC[all]='все видео'
DESC[new]='новое видео'
DESC[each_line]='после каждого скачанного файла'
DESC[in_the_end]='в конце всей загрузки'
DESC[sym_link_rel]='относительная символическая ссылка'
DESC[sym_link_abs]='абсолютная символическая ссылка'
DESC[hard_link]='жёсткая ссылка'

_select_list

case "$OPT_VIDLIST" in
all)
    VIDLIST="$VIDLIST_ALL"
    ind=$((VIDLIST_START))
    ;;
new)
    _select_update
    VIDLISTOLD="$VIDLIST_ALL"
    VIDLIST="$VIDLIST_NEW"
    ind=`wc -l<"$VIDLISTOLD"`
    ind=$((ind+1))
    ;;
*)
    exit 1
esac

_select_link_type

echo 'Выбран перечень: '${DESC[$OPT_VIDLIST]}
if [[ "$OPT_VIDLIST" == 'new' ]]; then
    echo 'Способ обновления перечня: '${DESC[$OPT_UPDATE]}
fi
echo 'Тип ссылки: '${DESC[$OPT_LINKTYPE]}

if [[ x`wc -l<"$VIDLIST"` == 'x0' ]]; then
    _msg 'Нечего скачивать.'
    exit
fi

_msg 'Поехали...'

mkdir -p "$OUTDIR"
mkdir -p "$YTDIR"

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
        VIDEO_JSON="$YTDIR/$VIDEO_ID"'.json'

        echo 'Загрузка служебной информации...'
        if [[ ! -f "$VIDEO_JSON" ]]; then
            youtube-dl --dump-json "$VIDEO_URL" >"$VIDEO_JSON"
        fi

        echo 'Извлечение служебной информации...'
        VIDEO_UPLOAD_DATE=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --get-filename -o "%(upload_date)s" "$VIDEO_URL"`
        VIDEO_DURATION=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --get-duration "$VIDEO_URL"`
        VIDEO_EXT=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --get-filename -o "%(ext)s" "$VIDEO_URL"`
        VIDEO_FILENAME="$YTDIR/$VIDEO_ID.$VIDEO_FORMAT_SELECT.$VIDEO_EXT"
        VIDEO_UPLOAD_DATE="${VIDEO_UPLOAD_DATE:0:4}-${VIDEO_UPLOAD_DATE:4:2}-${VIDEO_UPLOAD_DATE:6:2}"
        VIDEO_DESC="$YTDIR/$VIDEO_ID.description"
        VIDEO_COMMENT="$YTDIR/$VIDEO_ID.txt"
        VIDEO_THUMBNAIL_URL=`youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --get-thumbnail "$VIDEO_URL"`
        VIDEO_THUMBNAIL_EXT="${VIDEO_THUMBNAIL_URL##*.}"
        if [[ "$VIDEO_THUMBNAIL_URL" == "$VIDEO_THUMBNAIL_EXT" ]]; then
            VIDEO_THUMBNAIL_EXT=''
        fi
        VIDEO_THUMBNAIL="$YTDIR/$VIDEO_ID.$VIDEO_FORMAT_SELECT"
        if [[ ! -z "$VIDEO_THUMBNAIL_EXT" ]]; then
            VIDEO_THUMBNAIL="$VIDEO_THUMBNAIL.$VIDEO_THUMBNAIL_EXT"
        fi
        TARGET_NAME="$OUTDIR/$FILE_INDEX-$VIDEO_UPLOAD_DATE. $FILE_NAME"
        TARGET_FILENAME="$TARGET_NAME.$VIDEO_EXT"
        TARGET_COMMENT="$TARGET_NAME.txt"
        TARGET_THUMBNAIL="$TARGET_NAME"
        if [[ ! -z "$VIDEO_THUMBNAIL_EXT" ]]; then
            TARGET_THUMBNAIL="$TARGET_THUMBNAIL.$VIDEO_THUMBNAIL_EXT"
        fi

        echo 'Загрузка описания...'
        if [[ ! -f "$VIDEO_DESC" ]]; then
            youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --get-description "$VIDEO_URL" > "$VIDEO_DESC"
        fi

        echo 'Запись комментария...'
        if [[ ! -f "$VIDEO_COMMENT" ]]; then
            cat >"$VIDEO_COMMENT" <<EOT
$VIDEO_TITLE

Источник: $VIDEO_URL
Опубликовано: $VIDEO_UPLOAD_DATE
Длительность: $VIDEO_DURATION

EOT
            cat "$VIDEO_DESC" >>"$VIDEO_COMMENT"
        fi

        echo 'Загрузка малого изображения...'
        if [[ ! -f "$VIDEO_THUMBNAIL" ]]; then
            wget -q "$VIDEO_THUMBNAIL_URL" -O "$VIDEO_THUMBNAIL"
            #youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" --write-thumbnail -o "$VIDEO_THUMBNAIL" "$VIDEO_URL"
        fi

        echo 'Загрузка видео...'
        if [[ ! -f "$VIDEO_FILENAME" ]]; then
            youtube-dl -f $VIDEO_FORMAT_SELECT --load-info-json "$VIDEO_JSON" -o "$VIDEO_FILENAME" "$VIDEO_URL"
        fi

        echo 'Создание ссылок...'
        case "$OPT_LINKTYPE" in
        sym_link_rel)
            if [[ ! -e "$TARGET_COMMENT" ]]; then
                ln -r -s "$VIDEO_COMMENT" "$TARGET_COMMENT"
            fi
            if [[ ! -e "$TARGET_THUMBNAIL" ]]; then
                ln -r -s "$VIDEO_THUMBNAIL" "$TARGET_THUMBNAIL"
            fi
            if [[ ! -e "$TARGET_FILENAME" ]]; then
                ln -r -s "$VIDEO_FILENAME" "$TARGET_FILENAME"
            fi
            ;;
        sym_link_abs)
            if [[ ! -e "$TARGET_COMMENT" ]]; then
                ln -s `realpath $VIDEO_COMMENT` "$TARGET_COMMENT"
            fi
            if [[ ! -e "$TARGET_THUMBNAIL" ]]; then
                ln -s `realpath $VIDEO_THUMBNAIL` "$TARGET_THUMBNAIL"
            fi
            if [[ ! -e "$TARGET_FILENAME" ]]; then
                ln -s `realpath $VIDEO_FILENAME` "$TARGET_FILENAME"
            fi
            ;;
        hard_link)
            if [[ ! -e "$TARGET_COMMENT" ]]; then
                ln "$VIDEO_COMMENT" "$TARGET_COMMENT"
            fi
            if [[ ! -e "$TARGET_THUMBNAIL" ]]; then
                ln "$VIDEO_THUMBNAIL" "$TARGET_THUMBNAIL"
            fi
            if [[ ! -e "$TARGET_FILENAME" ]]; then
                ln "$VIDEO_FILENAME" "$TARGET_FILENAME"
            fi
            ;;
        *)
            ;;
        esac

    fi
    case "$OPT_VIDLIST" in
    all)
        ;;
    new)
        if [[ "$OPT_UPDATE" == 'each_line' ]]; then
            head -n 1 "$VIDLIST" >> "$VIDLISTOLD"
            tail -n +2 "$VIDLIST" > "$TMPFILE"
            mv "$TMPFILE" "$VIDLIST"
        fi
        ;;
    *)
        ;;
    esac
    ind=$((ind+1))
done <"$VIDLIST"

case "$OPT_VIDLIST" in
all)
    ;;
new)
    if [[ "$OPT_UPDATE" == 'in_the_end' ]]; then
        _msg 'Обновление списка видео...'
        cat "$VIDLIST" >> "$VIDLISTOLD"
        truncate -s 0 "$VIDLIST"
    fi
    ;;
*)
    exit 1
esac

if [[ -e "$TMPFILE" ]]; then rm "$TMPFILE"; fi
_msg 'Задание успешно завершено.'
