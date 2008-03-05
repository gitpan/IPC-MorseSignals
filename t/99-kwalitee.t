#!perl

use strict;
use warnings;

use Test::More;

plan(skip_all => 'XXX Testing with 5.8') if $^V lt v5.10;

eval { require Test::Kwalitee; Test::Kwalitee->import() };
plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;
