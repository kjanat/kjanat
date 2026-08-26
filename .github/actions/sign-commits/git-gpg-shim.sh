#!/usr/bin/env bash
# Bridges git's gpg.program contract to the gpg-signing-service client, so
# commit.gpgsign / tag.gpgSign sign through the service like a local key.
#
#   sign:   <prog> --status-fd=2 -bsau <key>  payload on stdin, armor on stdout
#   verify: <prog> --status-fd=1 --verify <sig> -   delegated to real gpg
#
# git accepts the signature only if it also sees [GNUPG:] SIG_CREATED on the
# status fd, so that line is synthesised here.
set -uo pipefail

status_fd=2
verify=0
key="${GPG_SIGN_KEY_ID:-}"
prev=""

for arg in "$@"; do
	case "${arg}" in
		--status-fd=*) status_fd="${arg#--status-fd=}" ;;
		--verify | --verify-files) verify=1 ;;
	esac
	# git emits the key as the argument following a combined flag ending in u
	# (-bsau) or an explicit -u/--local-user.
	case "${prev}" in
		-u | --local-user | -*u)
			[ "${arg#-}" = "${arg}" ] && key="${arg}"
			;;
	esac
	prev="${arg}"
done

if [ "${verify}" -eq 1 ]; then
	exec gpg "$@"
fi

if [ -n "${key}" ]; then
	signature="$(gpg-sign sign --key-id "${key}")" || exit 1
else
	signature="$(gpg-sign sign)" || exit 1
fi

printf '%s\n' "${signature}"
printf '[GNUPG:] SIG_CREATED B 1 8 00 %s %s\n' "$(date -u +%s)" "${key:-service}" >&"${status_fd}"
