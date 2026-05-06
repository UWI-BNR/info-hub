<div class="table-responsive bnr-download-table-wrap">

<table class="table table-sm table-hover align-middle bnr-download-table">
  <thead>
    <tr>
      <th scope="col">Area</th>
      <th scope="col">Period</th>
      <th scope="col">Output</th>
      <th scope="col">Artefact</th>
      <th scope="col">Format</th>
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
        String(item.briefing_id || "").trim() !== "" &&
        String(item.format || "").trim() !== ""
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

        <td class="listing-briefing_title">
          <%- item.briefing_title %>
        </td>

        <td class="listing-title">
          <%- item.title %>
          <span class="visually-hidden listing-artefact_type">
            <%- item.artefact_type %>
          </span>
        </td>

        <td class="listing-format">
          <span class="badge text-bg-light border">
            <%- item.format %>
          </span>
        </td>

        <td class="listing-updated">
          <%- item.updated %>
        </td>

        <td>
          <a class="btn btn-sm btn-outline-primary"
             href="<%- item.path %>"
             download>
             Download
          </a>
        </td>
      </tr>
    <% } %>
  </tbody>
</table>

</div>