-- Add the centrally controlled review-status strip used by the three BNR
-- manuals. Individual pages normally set only manual-review-status.

local show_status = false
local status_key = "not-reviewed"

local labels = {
  ["not-used"] = "Not used in this manual",
  ["not-reviewed"] = "Not reviewed",
  ["reviewed-by-irh"] = "Reviewed by IRH",
  ["approved-by-bnr"] = "Approved by BNR"
}

local function metadata_boolean(value, default)
  if value == nil then
    return default
  end
  if type(value) == "boolean" then
    return value
  end
  return pandoc.utils.stringify(value):lower() == "true"
end

function Meta(meta)
  show_status = metadata_boolean(meta["manual-review-display"], false)
  if meta["manual-review-status"] ~= nil then
    status_key = pandoc.utils.stringify(meta["manual-review-status"])
  end

  if labels[status_key] == nil then
    error(
      "Unknown manual-review-status '" .. status_key ..
      "'. Use not-used, not-reviewed, reviewed-by-irh or approved-by-bnr."
    )
  end

  return meta
end

function Pandoc(doc)
  if not show_status or not FORMAT:match("html") then
    return doc
  end

  -- Approved pages retain their YAML status for the internal review register,
  -- but are deliberately free of an editorial-status callout when published.
  if status_key == "approved-by-bnr" then
    return doc
  end

  local content = pandoc.Para({
    pandoc.Strong({pandoc.Str("Review status:")}),
    pandoc.Space(),
    pandoc.Str(labels[status_key])
  })

  local strip = pandoc.Div(
    {content},
    pandoc.Attr(
      "",
      {"bnr-manual-review-status", "bnr-manual-review-status--" .. status_key},
      {role = "note", ["aria-label"] = "Manual review status"}
    )
  )

  table.insert(doc.blocks, 1, strip)
  return doc
end
