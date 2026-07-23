async function loadFeed() {
  const candidates = [
    "./data/monitor_feed_real.json",
    "./data/monitor_feed_mock.json"
  ];

  for (const url of candidates) {
    try {
      const response = await fetch(url, { cache: "no-store" });
      if (response.ok) {
        const data = await response.json();
        console.log("Feed carregado:", url);
        return data;
      }
    } catch (error) {
      console.warn("Falha ao carregar feed:", url, error);
    }
  }

  throw new Error("Nenhum feed disponível para o monitor.");
}

function statusClass(status) {
  if (!status) return "";
  if (status.includes("READY")) return "ready";
  if (status.includes("PROBE")) return "probe";
  if (status.includes("REVIEW")) return "review";
  if (status.includes("TRIAGEM")) return "review";
  return "blocked";
}

function renderKpis(feed) {
  const el = document.querySelector("#kpis");
  el.innerHTML = feed.kpis.map(kpi => `
    <section class="card kpi">
      <div class="icon">${kpi.icon}</div>
      <small>${kpi.label}</small>
      <strong>${kpi.value}</strong>
      <span>${kpi.trend}</span>
    </section>
  `).join("");
}

function renderQueues(feed) {
  const el = document.querySelector("#queues");
  el.innerHTML = feed.queues.map(q => `
    <section class="card queue ${q.priority === "high" ? "high" : ""}">
      <small>${q.subtitle}</small>
      <h3>${q.event_id}<br>${q.label}</h3>
      <p>${q.count} registros</p>
      <a href="#" class="btn">${q.button}<span>→</span></a>
    </section>
  `).join("");
}

function renderEvents(feed) {
  const el = document.querySelector("#events");
  el.innerHTML = feed.events.map(event => `
    <div class="event-node ${event[0] === "EVT-007" ? "active" : ""}">
      <strong>${event[0]}</strong>
      <span>${event[1]}</span><br>
      <span>${event[2]}</span>
    </div>
  `).join("");
}

function renderOpportunities(feed) {
  const el = document.querySelector("#opportunities");
  el.innerHTML = feed.opportunities.map(item => `
    <tr>
      <td>${item.orgao}</td>
      <td>${item.processo}</td>
      <td>${item.fornecedor || "Não informado"}</td>
      <td>${item.fornecedor_cnpj || ""}</td>
      <td>${item.objeto}</td>
      <td>${item.modalidade || ""}</td>
      <td>${item.data_homologacao || ""}</td>
      <td>${item.evento}</td>
      <td><span class="status ${statusClass(item.status)}">${item.status}</span></td>
      <td>${item.valor}</td>
      <td>${item.rota}</td>
      <td>${item.atualizado}</td>
    </tr>
  `).join("");
}

function renderInsights(feed) {
  const groups = [
    feed.insights.slice(0, 2),
    feed.insights.slice(2, 4)
  ];

  document.querySelector("#insight-left").innerHTML = groups[0].map(i => `
    <div class="insight">
      <strong>${i.name}</strong>
      <p>${i.desc}</p>
    </div>
  `).join("");

  document.querySelector("#insight-right").innerHTML = groups[1].map(i => `
    <div class="insight">
      <strong>${i.name}</strong>
      <p>${i.desc}</p>
    </div>
  `).join("");
}

function renderBrand(feed) {
  document.querySelector("#brand-title").textContent = feed.brand.title;
  document.querySelector("#brand-subtitle").textContent = feed.brand.subtitle;
  document.querySelector("#signature-name").textContent = feed.brand.signature;
  document.querySelector("#signature-message").textContent = `"${feed.brand.message}"`;
}

loadFeed().then(feed => {
  renderBrand(feed);
  renderKpis(feed);
  renderQueues(feed);
  renderEvents(feed);
  renderOpportunities(feed);
  renderInsights(feed);
}).catch(error => {
  console.error(error);
  alert("Não foi possível carregar o feed do monitor.");
});
