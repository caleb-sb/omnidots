#!/usr/bin/env bash

echo /usr/bin/fish | sudo tee -a /etc/shells

chsh -s /usr/bin/fish
