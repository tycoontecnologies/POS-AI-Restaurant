"use client";

import { useEffect, useMemo, useState } from "react";
import { addDoc, collection, onSnapshot, query, limit, Firestore, Timestamp } from "firebase/firestore";
import { Search, RefreshCw, Database, FileText } from "lucide-react";

type ModuleKey = "dashboard" | "categories" | "customers" | "discounts" | "ingredients" | "purchases" | "purchase_returns" | "sales" | "sale_returns" | "suppliers" | "staff" | "attendance" | "store_out" | "branches" | "expenses" | "orders";
type Row = Record<string, unknown> & { id: string };
const modules: Record<ModuleKey, { title: string; collection: string; description: string }> = {
  dashboard: { title: "Dashboard", collection: "sales", description: "Live sales activity from your existing vendor workspace" },
  categories: { title: "Categories", collection: "categories", description: "Product category records" },
  customers: { title: "Customers", collection: "customers", description: "Customer directory and account records" },
  discounts: { title: "Discounts", collection: "discounts", description: "Configured discount records" },
  ingredients: { title: "Ingredients", collection: "ingredients", description: "Ingredient inventory records" },
  purchases: { title: "Purchases", collection: "purchases", description: "Supplier purchase records" },
  purchase_returns: { title: "Purchase returns", collection: "purchase_returns", description: "Purchase return records" },
  sales: { title: "Sales", collection: "sales", description: "Completed sale records" },
  sale_returns: { title: "Sales returns", collection: "sale_returns", description: "Sale return records" },
  suppliers: { title: "Suppliers", collection: "suppliers", description: "Supplier directory" },
  staff: { title: "Staff", collection: "staff", description: "Staff and employee records" },
  attendance: { title: "Attendance", collection: "attendance", description: "Staff attendance records" },
  store_out: { title: "Store out", collection: "store_out", description: "Stock movement and store-out records" },
  branches: { title: "Branches", collection: "branches", description: "Branch records" },
  expenses: { title: "Expenses", collection: "expenses", description: "Expense records" },
  orders: { title: "Orders", collection: "orders", description: "Order records" },
};

function display(value: unknown): string {
  if (value == null) return "—";
  if (typeof value === "object") {
    if ("seconds" in (value as object)) return new Date(Number((value as {seconds:number}).seconds) * 1000).toLocaleString();
    return JSON.stringify(value);
  }
  if (typeof value === "number") return value.toLocaleString("en-PK");
  return String(value);
}

export default function AdminWorkspace({ db, vendorId, moduleKey }: { db: Firestore; vendorId: string; moduleKey: ModuleKey }) {
  const config = modules[moduleKey];
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Row | null>(null);\n  const [formOpen, setFormOpen] = useState(false);\n  const [form, setForm] = useState<Record<string,string>>({});\n  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setLoading(true); setError("");
    const ref = collection(db, "vendors", vendorId, config.collection);
    const stop = onSnapshot(query(ref, limit(250)), snap => {
      setRows(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row)));
      setLoading(false);
    }, err => { setError(err.message); setLoading(false); });
    return () => stop();
  }, [db, vendorId, config.collection]);

  const filtered = useMemo(() => rows.filter(row => JSON.stringify(row).toLowerCase().includes(search.toLowerCase())), [rows, search]);
  const canCreate = ["categories","customers","suppliers","discounts","ingredients"].includes(moduleKey);\n  const formFields: Record<string,string[]> = { categories:["name","imageUrl"], customers:["name","phone","email","address","city"], suppliers:["name","phone","address"], discounts:["name","description","type","value","imageUrl"], ingredients:["name","unit","quantityInStock","lowStockThreshold"] };\n  async function createRecord(e: React.FormEvent) {\n    e.preventDefault(); if (!canCreate || saving) return; setSaving(true);\n    try {\n      const now = new Date(); const idRef = collection(db, "vendors", vendorId, config.collection);\n      let data: Record<string,unknown>;\n      if (moduleKey === "categories") data = { id: "", name: form.name?.trim() || "", active: true, imageUrl: form.imageUrl || "", createdOn: now.toISOString() };\n      else if (moduleKey === "customers") data = { id: "", name: form.name?.trim() || "", phone: form.phone || "", email: form.email || null, address: form.address || "", city: form.city || null, active: true, createdOn: Timestamp.fromDate(now), totalSpent: 0 };\n      else if (moduleKey === "suppliers") data = { id: "", name: form.name?.trim() || "", phone: form.phone || "", address: form.address || "", active: true, createdOn: Timestamp.fromDate(now), amountToReceive: 0, amountToPay: 0 };\n      else if (moduleKey === "discounts") data = { name: form.name?.trim() || "", description: form.description || "", type: form.type || "percentage", value: Number(form.value || 0), imageUrl: form.imageUrl || "", isActive: true, vendorId, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) };\n      else data = { id: "", name: form.name?.trim() || "", unit: form.unit || "g", quantityInStock: Number(form.quantityInStock || 0), lowStockThreshold: Number(form.lowStockThreshold || 20), createdOn: now.toISOString() };\n      const created = await addDoc(idRef, data); if (moduleKey !== "discounts") await (await import("firebase/firestore")).updateDoc(created, { id: created.id });\n      setForm({}); setFormOpen(false);\n    } catch (err) { setError(err instanceof Error ? err.message : "Unable to save record."); } finally { setSaving(false); }\n  }\n  const total = useMemo(() => rows.reduce((sum, row) => {
    const amount = Number(row.total ?? row.amount ?? row.totalAmount ?? 0);
    return sum + (Number.isFinite(amount) ? amount : 0);
  }, 0), [rows]);

  if (moduleKey === "dashboard") return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">BUSINESS OVERVIEW</p><h1>Dashboard</h1><p className="muted">Live records from this restaurant account</p></div><span className="live-pill"><span/> Live</span></div>
    <div className="admin-kpis"><article><small>Completed sales</small><strong>{rows.length}</strong></article><article><small>Recorded sales value</small><strong>{new Intl.NumberFormat("en-PK",{style:"currency",currency:"PKR",maximumFractionDigits:0}).format(total)}</strong></article><article><small>Latest activity</small><strong>{rows[0]?.createdAt || rows[0]?.createdOn ? display(rows[0].createdAt ?? rows[0].createdOn) : "—"}</strong></article></div>
    <div className="admin-note"><Database size={18}/> Dashboard totals reflect the latest 250 sales records available to this view. They are not a replacement for the Flutter analytics and reporting calculations.</div>
    <RecordsTable rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected}/>
  </section>;

  return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">MANAGEMENT</p><h1>{config.title}</h1><p className="muted">{config.description}</p></div><span className="count-badge">{rows.length} records</span></div>
    <RecordsTable rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected}/>
    <p className="admin-note"><FileText size={17}/> This migration view is intentionally read-only until each Flutter model's validation, permissions, and stock/billing side effects are ported and tested. No records are modified here.</p>
  </section>;
}

function RecordsTable({ rows, loading, error, search, setSearch, selected, setSelected }: { rows: Row[]; loading: boolean; error: string; search: string; setSearch: (s:string)=>void; selected: Row|null; setSelected: (r:Row|null)=>void }) {
  const keys = useMemo(() => {
    const preferred = ["name","number","customerName","supplierName","productName","status","total","amount","createdAt","createdOn"];
    const all = Array.from(new Set(rows.flatMap(r => Object.keys(r).filter(k => k !== "id"))));
    return [...preferred.filter(k => all.includes(k)), ...all.filter(k => !preferred.includes(k))].slice(0, 6);
  }, [rows]);
  return <>
    <div className="admin-toolbar"><div className="search-wrap"><Search size={17}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search records…"/></div><button className="secondary-btn" onClick={()=>setSearch("")}><RefreshCw size={15}/> Clear</button></div>
    {error&&<p className="error-text">{error}</p>}
    {loading?<div className="empty-state">Loading records…</div>:!rows.length?<div className="empty-state">No records found in this collection.</div>:<div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Document ID</th>{keys.map(k=><th key={k}>{k}</th>)}</tr></thead><tbody>{rows.map(row=><tr key={row.id} onClick={()=>setSelected(row)}><td><button className="record-link">{row.id}</button></td>{keys.map(k=><td key={k}>{display(row[k])}</td>)}</tr>)}</tbody></table></div>}
    {selected&&<div className="record-detail"><div className="record-detail-head"><strong>Record details</strong><button className="icon-btn" onClick={()=>setSelected(null)}>×</button></div><pre>{JSON.stringify(selected,null,2)}</pre></div>}
  </>;
}
