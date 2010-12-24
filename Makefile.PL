use inc::Module::Install;
name 'Cocoa-EventLoop';
all_from 'lib/Cocoa/EventLoop.pm';

test_requires 'Test::More';
use_test_base;
author_tests('xt');

auto_include;
auto_set_repository;

WriteAll;
