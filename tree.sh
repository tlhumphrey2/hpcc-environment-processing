#!/bin/bash -e
xmlfile=$1
egrep "<[A-Za-z]|<\/[A-Za-z]" $xmlfile|sed "s/^\( *<\/*[A-Za-z][A-Za-z0-9_]*\).*$/\1/" 
