#!/bin/sh

aws iam create-role          \
    --role-name xcodeinstall \
    --assume-role-policy-document file://ec2-role-trust-policy.json

aws iam create-policy                      \
    --policy-name xcodeinstall-permissions \
    --policy-document file://ec2-policy.json