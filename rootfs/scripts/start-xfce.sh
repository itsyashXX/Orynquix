#!/bin/sh
set -eu

xfce4-session &
session_pid=$!
(
    sleep 4
    /usr/local/libexec/orynquix/apply-appearance
) &
wait "$session_pid"
