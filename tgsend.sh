#!/usr/bin/env bash
# Send a message or an image to a Telegram chat

printHelp() {
cat << _help_
Usage:
  ${0##*/} --msg <message content>
  cat <message content file> | ${0##*/} --msg -
  ${0##*/} --img <path_to_image>

  Options:
    --msg <message>     - message ('-' - read from STDIN)
    --img <path>        - path to the image
    --chat <chatId>     - id of the Telegram chat (overrides --chat-nick)
    --chat-nick <nick>  - env or conf param to read chat id from
    --token-nick <nick> - env or conf param with Telegram API token to use

    --query <query str> - CGI-style query string
                        !!! Overrides above options and the QUERY_STRING
                        Allowed options: msg, img, chat, nick, token-nick.
                        For ex.:
                          'msg=%2Fstart&nick=mike&token-nick=adminBot'

    --quiet             - supress logging to SDTOUT
    --timeout <seconds> - timeout

Params (may be defined by either the env or the config files):
  defaultApiToken       - Telegram API token used by default
  defaultChat           - Optional Id of the chat to send to by default
  <any_nickname>        - Optional nickname(s) for Telegram chat(s)
  <any_token_nickname>  - Optional nickname(s) for Telegram token(s)
  QUERY_STRING          - CGI-style query string (--query overrides it)

Config files - shell scripts included via 'source ...' (if exist):
  /etc/tgsend/tgsend
  /run/secrets/tgsend
  /var/openfaas/secrets/tgsend
  $HOME/.tgsendrc

  For ex.:
  $ cat ~/.tgsendrc
  # Keep it private - whenever possible use Docker/k8s/OpenFaas secrets
  # Tokens:
  defaultApiToken=999999999:fffffffffffffffffffffffffffffffffff
  adminBot=888888888:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
  # Chats:
  mike=333333333
  team='-777777777'
  defaultChat=${team}
  #

  # Uncomment if used with OpenFaas
  export QUERY_STRING=${Http_Query}

_help_
}
[[ "$1" =~ ^-h|--help$ ]] && { printHelp; exit 1; }

log() {
	[ -z "${quiet}" ] && echo >&2 " [i] INFO:  $@"
}
log_error() {
	[ -z "${quiet}" ] && echo >&2 " [!] ERROR: $@"
}
panic() {
	log_error "${0##*/}: ERROR: $@"
	log "try \"${0##*/} --help\""
	log "${0##*/}: terminated"
	exit 3
}

# defaults
quiet=''
timeout=15

# include config file(s)
[ -f /etc/tgsend/tgsend ] && source /etc/tgsend/tgsend
[ -f /run/secrets/tgsend ] && source /run/secrets/tgsend
[ -f /var/openfaas/secrets/tgsend ] && source /var/openfaas/secrets/tgsend
[ -f $HOME/.tgsendrc ] && source $HOME/.tgsendrc

# local vars
msg=''
path_to_image=''
chat=''
chat_nick=''
token_nick=''
token=''

# parse params
while [[ $# -gt 0 ]]; do
key="$1"
	case ${key} in
		--msg=*)
			msg="${key#*=}"; shift ;;
		--msg)
			msg="$2"; shift; shift ;;
		--img=*)
			path_to_image="${key#*=}"; shift ;;
		--img)
			path_to_image="$2"; shift; shift ;;
		--chat=*)
			chat="${key#*=}"; shift ;;
		--chat)
			chat="$2"; shift; shift ;;
		--chat-nick=*)
			chat_nick="${key#*=}"; shift ;;
		--chat-nick)
			chat_nick="$2"; shift; shift ;;
		--token-nick=*)
			token_nick="${key#*=}"; shift ;;
		--token-nick)
			token_nick="$2"; shift; shift ;;
		--query=*)
			QUERY_STRING="${key#*=}"; shift ;;
		--query)
			QUERY_STRING="$2"; shift; shift ;;
		--timeout=*)
			timeout="${key#*=}"; shift ;;
		--timeout)
			timeout="$2"; shift; shift ;;
		--quiet)
			quiet="yes"; shift ;;
		*)
			panic "unknown option ${key}"
			;;
	esac
done

parse_query() {
        saveIFS="${IFS}"
	IFS='=&'
        parm=(${QUERY_STRING})
        IFS="${saveIFS}"
        for ((i=0; i<${#parm[@]}; i+=2)); do
                [[ ${parm[i]} =~ ^(msg|img|chat|chat-nick|token-nick)$ ]] \
			&& export ${parm[i]/-/_}=${parm[i+1]}
        done
}

defineToken() {
	[ -n "${token_nick}" ] \
		&& token=$(echo ${!token_nick}) \
		|| token=${defaultApiToken}
}

defineChatId() {
	[ -n "${chat_nick}" ] && chat=$(echo ${!chat_nick})
	[ -n "${chat}" ] && chatId=${chat} || chatId=${defaultChat}
}

read_msg_from_stdin() {	cat; }

send() {
	curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
		-d text="${message}" \
		-d chat_id="${chatId}"
}

send_image() {
	curl -s "https://api.telegram.org/bot${token}/sendPhoto?chat_id=${chatId}" \
		-F "photo=@${path_to_image}"
}

main() {
	[ -n "QUERY_STRING" ] && parse_query

	defineToken
	[ -z "${token}" ] && panic "Telegram API Token undefined"

	defineChatId
	[ -z "${chatId}" ] && panic "Telegram chat id undefined"

	[[ -z "${path_to_image}" ]] && {
		log "$(date): sending message"
		message="${msg}"
		[[ "${msg}" == '-' ]] && message="$(read_msg_from_stdin)"
		[[ -z "$message" ]] && panic "empty message"
		send
	} || {
		log "$(date): sending file ${path_to_image}"
		[[ -z "$path_to_image" ]] && panic "image file unspecified"
		[[ -f "$path_to_image" ]] || panic "image file not found"
		send_image
	}

}

main
