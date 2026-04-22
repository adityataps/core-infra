#!/usr/bin/env bash
# Shared configuration for all tf-* scripts.
# Source this file — do not execute it directly.
#
# Note: Terraform remote_state data blocks in .tf files still contain this bucket
# name as a string literal (Terraform does not allow variables in backend configs).
# This file centralizes the name for bash scripts only.

STATE_BUCKET="tapshalkar-com-tfstate"
