"use client";

import { useEffect, useMemo, useState } from "react";
import { addDoc, collection, doc, onSnapshot, query, limit, Firestore, Timestamp, updateDoc, deleteDoc } from "firebase/firestore";
import { Search, RefreshCw, Database, FileText } from "lucide-react";
import { getDownloadURL, ref as storageRef, deleteObject, uploadBytes, type FirebaseStorage } from "firebase/storage";

type ModuleKey = "dashboard" | "products" | "categories" | "customers" | "discounts" | "ingredients" | "purchases" | "purchase_returns" | "sales" | "sale_returns" | "suppliers" | "staff" | "attendance" | "store_out" | "branches" | "expenses" | "orders";
type Row = Record<string, unknown> & { id: string };

const modules: Record<ModuleKey, { title: string; collection: string; description: string }> = {
  dashboard: { title: "Dashboard", collection: "sales", description: "Live sales activity from your existing vendor workspace" },
  products: { title: "Products", collection: "products", description: "Product catalog and stock records" },
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
  store_out: { title: "Store out", collection: "store_outs", description: "Stock movement and store-out records" },
  branches: { title: "Branches", collection: "branches", description: "Branch records" },
  expenses: { title: "Expenses", collection: "expenses", description: "Expense records" },
  orders: { title: "Orders", collection: "orders", description: "Order records" },
};

const editableModules: ModuleKey[] = ["products", "categories", "customers", "suppliers", "discounts", "ingredients", "staff", "expenses"];
const fields: Record<string, string[]> = {
  products: ["name", "category", "unit", "salePrice", "purchasePrice", "quantity", "variantsJson", "imageUrl"],
  categories: ["name", "imageUrl"],
  customers: ["name", "phone", "email", "address", "city"],
  suppliers: ["name", "phone", "address"],
  discounts: ["name", "description", "type", "value", "imageUrl"],
  ingredients: ["name", "unit", "quantityInStock", "lowStockThreshold"],
  staff: ["name", "role", "dailyWage", "phone", "address", "active", "joinDate", "commissionRate", "showCommissionToStaff"],
  expenses: ["category", "amount", "note"],
};

function display(value: unknown): string {
  if (value == null) return "—";
  if (typeof value === "object") {
    if ("seconds" in (value as object)) return new Date(Number((value as { seconds: number }).seconds) * 1000).toLocaleString();
    return JSON.stringify(value);
  }
  return typeof value === "number" ? value.toLocaleString("en-PK") : String(value);
}

export default function AdminWorkspace({ db, vendorId, moduleKey, onReprint, storage, actorName = "Next.js POS", actorId = vendorId, branchId = "", branchName = "" }: { db: Firestore; vendorId: string; moduleKey: ModuleKey; storage: FirebaseStorage | null; onReprint?:(row:Row)=>void; actorName?:string; actorId?:string; branchId?:string; branchName?:string }) {
  const config = modules[moduleKey];
  const canEdit = editableModules.includes(moduleKey);
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Row | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [imageFile, setImageFile] = useState<File | null>(null);

  useEffect(() => {
    setLoading(true);
    setError("");
    const ref = collection(db, "vendors", vendorId, config.collection);
    const stop = onSnapshot(query(ref, limit(250)), snap => {
      setRows(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row)));
      setLoading(false);
    }, err => {
      setError(err.message);
      setLoading(false);
    });
    return () => stop();
  }, [db, vendorId, config.collection]);

  const filtered = useMemo(
    () => rows.filter(row => JSON.stringify(row).toLowerCase().includes(search.toLowerCase())),
    [rows, search],
  );
  const total = useMemo(() => rows.reduce((sum, row) => {
    const amount = Number(row.total ?? row.amount ?? row.totalAmount ?? 0);
    return sum + (Number.isFinite(amount) ? amount : 0);
  }, 0), [rows]);

  function beginCreate() {
    setEditingId(null);
    setForm({});
    setFormOpen(true);
  }

  function beginEdit(row: Row) {
    setEditingId(row.id);
    setForm(Object.fromEntries((fields[moduleKey] || []).map(field => [field, field === "variantsJson" ? JSON.stringify(row.variants || [], null, 2) : String(row[field] ?? "")])));
    setFormOpen(true);
  }

  function makePayload(now: Date): Record<string, unknown> {
    if (moduleKey === "products") {
      const parsed = form.variantsJson?.trim() ? JSON.parse(form.variantsJson) : [];
      if (!Array.isArray(parsed) || parsed.some(v => !v || typeof v !== "object" || Array.isArray(v))) throw new Error("Variants must be a JSON array of objects.");
      const variants = parsed.map((v: Record<string, unknown>) => ({
        id: String(v.id || crypto.randomUUID()),
        name: String(v.name || ""),
        priceModifier: Number(v.priceModifier || 0),
        quantity: Number(v.quantity || 0),
        active: v.active !== false,
        attributes: v.attributes && typeof v.attributes === "object" ? v.attributes : {},
      }));
      if (variants.some(v => !v.name)) throw new Error("Every variant needs a name.");
      return {
        name: form.name?.trim() || "", category: form.category || "", unit: form.unit || "piece",
        salePrice: Number(form.salePrice || 0), purchasePrice: Number(form.purchasePrice || 0),
        quantity: Number(form.quantity || 0), hasVariants: variants.length > 0, variants,
        imageUrl: form.imageUrl || "",
      };
    }
    if (moduleKey === "categories") return { name: form.name?.trim() || "", imageUrl: form.imageUrl || "" };
    if (moduleKey === "expenses") {
      const amount = Number(form.amount || 0);
      if (!Number.isFinite(amount) || amount <= 0) throw new Error("Expense amount must be greater than zero.");
      return { category: form.category || "General", amount, note: form.note?.trim() || "" };
    }
    if (moduleKey === "staff") {
      const name = form.name?.trim() || "";
      const role = form.role?.trim() || "";
      if (!name || !role) throw new Error("Staff name and role are required.");
      const joinDate = form.joinDate || new Date().toISOString().slice(0, 10);
      return { name, role, dailyWage: Math.max(0, Number(form.dailyWage || 0)), phone: form.phone || "", address: form.address || "", active: form.active !== "false", joinDate: new Date(joinDate + "T00:00:00").toISOString(), searchKeywords: Array.from(new Set([name.toLowerCase(), role.toLowerCase(), (form.phone || "").toLowerCase(), ...name.toLowerCase().split(" "), ...role.toLowerCase().split(" ")].filter(Boolean))), commissionRate: Math.max(0, Number(form.commissionRate || 0)), showCommissionToStaff: form.showCommissionToStaff === "true" };
    }
    if (moduleKey === "customers") return { name: form.name?.trim() || "", phone: form.phone || "", email: form.email || null, address: form.address || "", city: form.city || null };
    if (moduleKey === "suppliers") return { name: form.name?.trim() || "", phone: form.phone || "", address: form.address || "" };
    if (moduleKey === "discounts") return { name: form.name?.trim() || "", description: form.description || "", type: form.type || "percentage", value: Number(form.value || 0), imageUrl: form.imageUrl || "" };
    return { name: form.name?.trim() || "", unit: form.unit || "g", quantityInStock: Number(form.quantityInStock || 0), lowStockThreshold: Number(form.lowStockThreshold || 20) };
  }

  async function saveRecord(e: React.FormEvent) {
    e.preventDefault();
    if (!canEdit || saving) return;
    setSaving(true);
    setError("");
    try {
      const now = new Date();
      const payload = makePayload(now);
      const ref = collection(db, "vendors", vendorId, config.collection);
      let recordId = editingId;
      if (editingId) {
        const patch = moduleKey === "discounts"
          ? { ...payload, updatedAt: Timestamp.fromDate(now) }
          : payload;
        await updateDoc(doc(db, "vendors", vendorId, config.collection, editingId), patch);
      } else {
        let data: Record<string, unknown> = { ...payload };
        if (moduleKey === "products") data = { ...data, id: "", active: true, createdOn: now.toISOString(), attributes: [] };
        if (moduleKey === "categories") data = { ...data, id: "", active: true, createdOn: now.toISOString() };
        if (moduleKey === "customers") data = { ...data, id: "", active: true, createdOn: Timestamp.fromDate(now), totalSpent: 0 };
        if (moduleKey === "expenses") data = { ...data, createdAt: serverTimestamp(), createdBy: actorName, createdById: actorId, branchId, branchName };
        if (moduleKey === "staff") data = { ...data, id: "", tipsEarned: 0, commissionEarned: 0, serviceChargesEarned: 0, pointsEarned: 0, averageRating: 0, reviewCount: 0, leakageTotal: 0, deductionsTotal: 0 };
        if (moduleKey === "suppliers") data = { ...data, id: "", active: true, createdOn: Timestamp.fromDate(now), amountToReceive: 0, amountToPay: 0 };
        if (moduleKey === "discounts") data = { ...data, isActive: true, vendorId, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) };
        if (moduleKey === "ingredients") data = { ...data, id: "", createdOn: now.toISOString() };
        const created = await addDoc(ref, data);
        recordId = created.id;
        if (moduleKey !== "discounts") await updateDoc(created, { id: created.id });
      }
      if (imageFile && recordId && ["products", "categories", "discounts"].includes(moduleKey)) {
        if (!storage) throw new Error("Firebase Storage is not configured.");
        if (imageFile.size > 5 * 1024 * 1024) throw new Error("Image must be smaller than 5 MB.");
        if (!imageFile.type.startsWith("image/")) throw new Error("Choose a valid image file.");
        const extension = imageFile.name.includes(".") ? imageFile.name.slice(imageFile.name.lastIndexOf(".")) : ".jpg";
        const folder = moduleKey === "products" ? "products" : moduleKey === "categories" ? "categories" : "discounts";
        const prefix = moduleKey === "products" ? "product" : moduleKey === "categories" ? "category" : "discount";
        const destination = storageRef(storage, "vendors/" + vendorId + "/" + folder + "/" + recordId + "/" + prefix + "_" + Date.now() + extension);
        const uploaded = await uploadBytes(destination, imageFile, { contentType: imageFile.type });
        const newUrl = await getDownloadURL(uploaded.ref);
        await updateDoc(doc(db, "vendors", vendorId, config.collection, recordId), { imageUrl: newUrl });
        const oldUrl = rows.find(row => row.id === recordId)?.imageUrl;
        if (typeof oldUrl === "string" && oldUrl && oldUrl !== newUrl) { try { await deleteObject(storageRef(storage, oldUrl)); } catch { /* old image cleanup is best-effort */ } }
      }
      setForm({});
      setImageFile(null);
      setEditingId(null);
      setFormOpen(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save record.");
    } finally {
      setSaving(false);
    }
  }

  if (moduleKey === "dashboard") return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">BUSINESS OVERVIEW</p><h1>Dashboard</h1><p className="muted">Live records from this restaurant account</p></div><span className="live-pill"><span/> Live</span></div>
    <div className="admin-kpis"><article><small>Completed sales (latest 250)</small><strong>{rows.length}</strong></article><article><small>Recorded sales value</small><strong>{new Intl.NumberFormat("en-PK", { style: "currency", currency: "PKR", maximumFractionDigits: 0 }).format(total)}</strong></article><article><small>Latest activity</small><strong>{rows[0]?.createdAt || rows[0]?.createdOn ? display(rows[0].createdAt ?? rows[0].createdOn) : "—"}</strong></article></div>
    <div className="admin-note"><Database size={18}/> This is a live record summary, not a replacement for the Flutter analytics/reporting calculations.</div>
    <RecordsTable rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected}/>
  </section>;

  return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">MANAGEMENT</p><h1>{config.title}</h1><p className="muted">{config.description}</p></div><div className="admin-head-actions"><span className="count-badge">{rows.length} records</span>{canEdit && <button className="primary-btn" onClick={beginCreate}>+ Add new</button>}</div></div>
    {formOpen && <form className="admin-create-form" onSubmit={saveRecord}>
      <div className="record-detail-head"><strong>{editingId ? "Edit" : "New"} {config.title.replace(/s$/, "")}</strong><button type="button" className="icon-btn" onClick={() => { setFormOpen(false); setEditingId(null); }}>×</button></div>
      <div className="admin-form-grid">{(fields[moduleKey] || []).map(field => <label key={field}>{field.replace(/([A-Z])/g, " $1")}{field === "variantsJson" && <textarea rows={6} value={form[field] || "[]"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}></textarea>}{field !== "variantsJson" && <input required={field === "name"} type={["value", "salePrice", "purchasePrice", "quantity", "quantityInStock", "lowStockThreshold"].includes(field) ? "number" : "text"} step="any" value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}/>}{field === "imageUrl" && ["products", "categories", "discounts"].includes(moduleKey) && <input type="file" accept="image/*" onChange={e => setImageFile(e.target.files?.[0] || null)}/>}</label>)}</div>
      <button className="primary-btn" disabled={saving}>{saving ? "Saving…" : editingId ? "Update record" : "Save record"}</button>
    </form>}
    <RecordsTable rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected} canEdit={canEdit} onEdit={beginEdit} onReprint={moduleKey==="sales"?onReprint:undefined} canDelete={moduleKey==="expenses"} onDelete={moduleKey==="expenses"?async row=>{if(!window.confirm("Delete this expense record?"))return;try{await deleteDoc(doc(db,"vendors",vendorId,config.collection,row.id));setSelected(null)}catch(err){setError(err instanceof Error?err.message:"Unable to delete expense.")}}:undefined}/>
    <p className="admin-note"><FileText size={17}/> This module is a migration slice. Unsupported workflow side effects, permissions and validations are not simulated here.</p>
  </section>;
}

function RecordsTable({ rows, loading, error, search, setSearch, selected, setSelected, canEdit = false, onEdit, onReprint, canDelete = false, onDelete }: {
  rows: Row[]; loading: boolean; error: string; search: string; setSearch: (s: string) => void;
  selected: Row | null; setSelected: (r: Row | null) => void; canEdit?: boolean; onEdit?: (r: Row) => void; onReprint?:(r:Row)=>void; canDelete?: boolean; onDelete?: (r:Row)=>void;
}) {
  const keys = useMemo(() => {
    const preferred = ["name", "number", "customerName", "supplierName", "productName", "status", "total", "amount", "createdAt", "createdOn"];
    const all = Array.from(new Set(rows.flatMap(r => Object.keys(r).filter(k => k !== "id"))));
    return [...preferred.filter(k => all.includes(k)), ...all.filter(k => !preferred.includes(k))].slice(0, 6);
  }, [rows]);
  return <>
    <div className="admin-toolbar"><div className="search-wrap"><Search size={17}/><input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search records…"/></div><button className="secondary-btn" onClick={() => setSearch("")}><RefreshCw size={15}/> Clear</button></div>
    {error && <p className="error-text">{error}</p>}
    {loading ? <div className="empty-state">Loading records…</div> : !rows.length ? <div className="empty-state">No records found in this collection.</div> : <div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Document ID</th>{keys.map(k => <th key={k}>{k}</th>)}</tr></thead><tbody>{rows.map(row => <tr key={row.id} onClick={() => setSelected(row)}><td><button className="record-link">{row.id}</button></td>{keys.map(k => <td key={k}>{display(row[k])}</td>)}</tr>)}</tbody></table></div>}
    {selected && <div className="record-detail"><div className="record-detail-head"><strong>Record details</strong><div className="record-actions">{canEdit && onEdit && <button className="secondary-btn" onClick={() => onEdit(selected)}>Edit record</button>}{canDelete && onDelete && <button className="secondary-btn danger-btn" onClick={() => onDelete(selected)}>Delete record</button>}{onReprint&&<button className="secondary-btn" onClick={()=>onReprint(selected)}>Reprint receipt</button>}<button className="icon-btn" onClick={() => setSelected(null)}>×</button></div></div><pre>{JSON.stringify(selected, null, 2)}</pre></div>}
  </>;
}
