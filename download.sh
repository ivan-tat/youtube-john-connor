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
#   GNU coreutils, bash, [dialog | whiptail], youtube-dl, wget.

set -e

BACKTITLE='Простое скачивание перечня видео-файлов с сервиса YouTube'

TMPFILE=tmp
VL_ALL='video-all.txt'
VL_NEW='video-new.txt'
VL_START='1'
OUTDIR='video'
YTDIR="$OUTDIR/youtube"

declare DIALOG
declare -i DIALOG_CLEAR
declare -A DESC
declare OPT_VL
declare OPT_UPDATE
declare OPT_LINKTYPE
declare -i ind

_msg() {
    echo "$1" >&2
}

_select_list() {
if [[ -z "$DIALOG" ]]; then
    select OPT_VL in "${DESC[all]}" "${DESC[new]}" "выход"; do
        case "$REPLY" in
        1)
            OPT_VL=all
            break
            ;;
        2)
            OPT_VL=new
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
    read OPT_VL < "$TMPFILE" || true
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

case "$OPT_VL" in
all)
    VL="$VL_ALL"
    ind=$((VL_START))
    ;;
new)
    _select_update
    VLOLD="$VL_ALL"
    VL="$VL_NEW"
    ind=`wc -l<"$VLOLD"`
    ind=$((ind+1))
    ;;
*)
    exit 1
esac

_select_link_type

echo 'Выбран перечень: '${DESC[$OPT_VL]}
if [[ "$OPT_VL" == 'new' ]]; then
    echo 'Способ обновления перечня: '${DESC[$OPT_UPDATE]}
fi
echo 'Тип ссылки: '${DESC[$OPT_LINKTYPE]}

if [[ x`wc -l<"$VL"` == 'x0' ]]; then
    _msg 'Нечего скачивать.'
    exit
fi

_msg 'Поехали...'

mkdir -p "$OUTDIR" "$YTDIR"

while read L; do
    if [[ x"${L:0:1}" != 'x#' ]]; then
        V_ID="${L%%|*}"
        V_URL='https://www.youtube.com/watch?v='"$V_ID"
        L="${L#*|}"
        V_FORMAT="${L%%|*}"
        L="${L#*|}"
        V_TITLE="${L%%|*}"
        F_TITLE="${L#*|}"
        F_INDEX=`printf '%03d' $ind`
        _msg 'Загрузка видео:'
        _msg "  Номер файла: $F_INDEX"
        _msg "  Код видео: $V_ID"
        _msg "  Ссылка: $V_URL"
        _msg "  Формат видео: $V_FORMAT"
        _msg "  Заголовок: $V_TITLE"
        _msg "  Имя файла: $F_TITLE"
        F_NAME="$YTDIR/$V_ID"
        F_JSON="$F_NAME.json"

        if [[ -f "$F_JSON" ]]; then
            echo 'Служебная информация уже сохранена.'
        else
            echo 'Загрузка служебной информации...'
            youtube-dl --dump-json "$V_URL" >"$F_JSON"
        fi

        echo 'Извлечение служебной информации...'
        cmd='youtube-dl --skip-download --load-info-json'
        V_UPLOAD_DATE=`$cmd "$F_JSON" --get-filename -o "%(upload_date)s" &`
        V_DURATION=`$cmd "$F_JSON" --get-duration &`
        V_DESCRIPTION=`$cmd "$F_JSON" --get-description &`
        F_THUMBNAIL_URL=`$cmd "$F_JSON" --get-thumbnail &`
        F_VIDEO_EXT=`$cmd "$F_JSON" -f "$V_FORMAT" --get-filename -o "%(ext)s" &`
        wait
        V_UPLOAD_DATE="${V_UPLOAD_DATE:0:4}-${V_UPLOAD_DATE:4:2}-${V_UPLOAD_DATE:6:2}"
        F_VIDEO="$F_NAME.$V_FORMAT.$F_VIDEO_EXT"
        F_COMMENT="$F_NAME.txt"
        F_THUMBNAIL_EXT="${F_THUMBNAIL_URL##*.}"
        if [[ "$F_THUMBNAIL_URL" == "$F_THUMBNAIL_EXT" ]]; then
            F_THUMBNAIL_EXT=''
        fi
        if [[ -z "$F_THUMBNAIL_EXT" ]]; then
            F_THUMBNAIL="$F_NAME.thumbnail"
        else
            F_THUMBNAIL="$F_NAME.$F_THUMBNAIL_EXT"
        fi
        if [[ -f "$F_COMMENT" ]]; then
            echo 'Комментарий уже сохранён.'
        else
            echo 'Запись комментария...'
            cat >"$F_COMMENT" <<EOF
$V_TITLE

Источник: $V_URL
Опубликовано: $V_UPLOAD_DATE
Длительность: $V_DURATION

$V_DESCRIPTION
EOF
        fi

        if [[ -f "$F_THUMBNAIL" ]]; then
            echo 'Малое изображение уже сохранено.'
        else
            echo 'Загрузка малого изображения...'
            wget -q "$F_THUMBNAIL_URL" -O "$F_THUMBNAIL"
        fi

        if [[ -f "$F_VIDEO" ]]; then
           echo 'Видео уже сохранено.'
        else
            echo 'Загрузка видео...'
            youtube-dl --load-info-json "$F_JSON" -f "$V_FORMAT" -o "$F_VIDEO" "$V_URL"
        fi

        echo 'Создание ссылок...'
        T_NAME="$OUTDIR/$F_INDEX-$V_UPLOAD_DATE. $F_TITLE"
        T_VIDEO="$T_NAME.$F_VIDEO_EXT"
        T_COMMENT="$T_NAME.txt"
        if [[ -z "$F_THUMBNAIL_EXT" ]]; then
            T_THUMBNAIL="$T_NAME.thumbnail"
        else
            T_THUMBNAIL="$T_NAME.$F_THUMBNAIL_EXT"
        fi
        case "$OPT_LINKTYPE" in
        sym_link_rel)
            if [[ ! -e "$T_COMMENT" ]]; then
                ln -r -s "$F_COMMENT" "$T_COMMENT"
            fi
            if [[ ! -e "$T_THUMBNAIL" ]]; then
                ln -r -s "$F_THUMBNAIL" "$T_THUMBNAIL"
            fi
            if [[ ! -e "$T_VIDEO" ]]; then
                ln -r -s "$F_VIDEO" "$T_VIDEO"
            fi
            ;;
        sym_link_abs)
            if [[ ! -e "$T_COMMENT" ]]; then
                ln -s `realpath "$F_COMMENT"` "$T_COMMENT"
            fi
            if [[ ! -e "$T_THUMBNAIL" ]]; then
                ln -s `realpath "$F_THUMBNAIL"` "$T_THUMBNAIL"
            fi
            if [[ ! -e "$T_VIDEO" ]]; then
                ln -s `realpath "$F_VIDEO"` "$T_VIDEO"
            fi
            ;;
        hard_link)
            if [[ ! -e "$T_COMMENT" ]]; then
                ln "$F_COMMENT" "$T_COMMENT"
            fi
            if [[ ! -e "$T_THUMBNAIL" ]]; then
                ln "$F_THUMBNAIL" "$T_THUMBNAIL"
            fi
            if [[ ! -e "$T_VIDEO" ]]; then
                ln "$F_VIDEO" "$T_VIDEO"
            fi
            ;;
        *)
            ;;
        esac

    fi
    case "$OPT_VL" in
    all)
        ;;
    new)
        if [[ "$OPT_UPDATE" == 'each_line' ]]; then
            head -n 1 "$VL" >> "$VLOLD"
            tail -n +2 "$VL" > "$TMPFILE"
            mv "$TMPFILE" "$VL"
        fi
        ;;
    *)
        ;;
    esac
    ind=$((ind+1))
done <"$VL"

case "$OPT_VL" in
all)
    ;;
new)
    if [[ "$OPT_UPDATE" == 'in_the_end' ]]; then
        _msg 'Обновление списка видео...'
        cat "$VL" >> "$VLOLD"
        truncate -s 0 "$VL"
    fi
    ;;
*)
    exit 1
esac

if [[ -f "$TMPFILE" ]]; then rm "$TMPFILE"; fi
_msg 'Задание успешно завершено.'
