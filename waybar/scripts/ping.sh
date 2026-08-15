#!/bin/bash
ping -c 1 1.1.1.1 | awk -F'/' 'END {print "PING " int($5) "ms"}'
