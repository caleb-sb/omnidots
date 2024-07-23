local cmp = require("cmp")
return {
  "hrsh7th/nvim-cmp",
  opts = {
    mapping = cmp.mapping.preset.insert({
      ["<Tab>"] = cmp.mapping.confirm({ select = true }),
      ["<CR>"] = function(fallback)
        cmp.abort()
        fallback()
      end,
    })
  }
}
