<div class="table-responsive bnr-download-table-wrap">

<table class="table table-sm table-hover align-middle bnr-download-table">
  <thead>
    <tr>
      <th scope="col">Area</th>
      <th scope="col">Period</th>
      <th scope="col">Type</th>
      <th scope="col">Output</th>
      <th scope="col">Contents</th>
      <th scope="col">Updated</th>
      <th scope="col">Download</th>
    </tr>
  </thead>

  <tbody class="list">
    <%
      const validItems = items.filter((item) =>
        item &&
        String(item.path || "").trim() !== "" &&
        String(item.title || "").trim() !== "" &&
        String(item.output_id || "").trim() !== "" &&
        String(item.format || "").trim().toUpperCase() === "ZIP"
      );
    %>

    <% for (const item of validItems) { %>
      <tr <%= metadataAttrs(item) %>>
        <td class="listing-surveillance_area">
          <%- item.surveillance_area %>
        </td>

        <td class="listing-period">
          <%- item.period %>
        </td>

        <td class="listing-output_type">
          <%- item.output_type %>
        </td>

        <td class="listing-output_title">
          <%- item.output_title %>
        </td>

        <td class="listing-description">
          <%- item.description || item.title %>

          <span class="visually-hidden listing-title">
            <%- item.title %>
          </span>

          <span class="visually-hidden listing-artefact_type">
            <%- item.artefact_type %>
          </span>

          <span class="visually-hidden listing-format">
            <%- item.format %>
          </span>

          <span class="visually-hidden listing-output_id">
            <%- item.output_id %>
          </span>
        </td>

        <td class="listing-updated">
          <%- item.updated %>
        </td>

        <td>
          <a class="btn btn-sm btn-outline-primary"
             href="<%- item.path %>"
             download>
             ZIP
          </a>
        </td>
      </tr>
    <% } %>
  </tbody>
</table>

</div>
