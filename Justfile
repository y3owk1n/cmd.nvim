doc:
    vimcats -t -f -c -a \
    lua/cmd/init.lua \
    > doc/cmd.nvim.txt

set shell := ["bash", "-cu"]

test:
    @echo "Running tests in headless Neovim using test_init.lua..."
    nvim -l tests/minit.lua --minitest
