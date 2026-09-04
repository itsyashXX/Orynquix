#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$PROJECT_ROOT"

failed=0
if rg -n --glob '*.sh' --glob 'bin/orynquix' '(chmod[[:space:]]+-R[[:space:]]+777|rm[[:space:]]+-rf[[:space:]]+(/|\*|\$HOME|~)([[:space:]]|$)|http://[^[:space:]]+\|[[:space:]]*(ba)?sh|\beval[[:space:]])' .; then
    printf 'Unsafe shell pattern detected.\n' >&2
    failed=1
fi

if rg -n --glob '*.sh' --glob '*.conf' --glob '!tests/static-safety.sh' '(9258793869|itsyashxx@gmail\.com|POCO|7\.3[[:space:]]*GiB|Android[[:space:]]+15)' .; then
    printf 'Creator-specific runtime data detected.\n' >&2
    failed=1
fi

if rg -n --glob '*.sh' '(PASSWORD|TOKEN|SECRET)=[^"$[:space:]][^[:space:]]+' .; then
    printf 'Possible hardcoded secret detected.\n' >&2
    failed=1
fi

(( failed == 0 ))
printf 'Static safety checks passed.\n'
