"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { initializeApp, deleteApp } from "firebase/app";
import { getAuth, createUserWithEmailAndPassword, sendPasswordResetEmail, deleteUser, signOut } from "firebase/auth";
import { firebaseApp } from "../lib/firebase";
import { addDoc, collection, doc, onSnapshot, query, limit, Firestore, Timestamp, updateDoc, deleteDoc, getDocs, getDoc, setDoc, writeBatch, where, serverTimestamp, orderBy, startAfter, type QueryDocumentSnapshot, type DocumentData } from "firebase/firestore";
import { Search, RefreshCw, Database, FileText } from "lucide-react";
import { getDownloadURL, ref as storageRef, deleteObject, uploadBytes, type FirebaseStorage } from "firebase/storage";

type ModuleKey = "dashboard" | "products" | "categories" | "customers" | "discounts" | "ingredients" | "purchases" | "purchase_returns" | "sales" | "sale_returns" | "suppliers" | "staff" | "attendance" | "store_out" | "branches" | "expenses" | "orders" | "users_roles";
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
  branches: { title: "Branches", collection: "branches", description: "Multi-branch locations and active status" },
  expenses: { title: "Expenses", collection: "expenses", description: "Expense records" },
  orders: { title: "Orders", collection: "orders", description: "Order records" },
  users_roles: { title: "Users & roles", collection: "vendors", description: "Department accounts and role permissions" },
};

const editableModules: ModuleKey[] = ["products", "categories", "customers", "suppliers", "discounts", "ingredients", "staff", "expenses", "attendance", "purchases", "purchase_returns", "sale_returns", "store_out", "branches"];
const fields: Record<string, string[]> = {
  products: ["name", "category", "unit", "salePrice", "purchasePrice", "quantity", "active", "hasVariants", "variantsJson", "attributesJson", "imageUrl"],
  categories: ["name", "imageUrl", "active"],
  customers: ["name", "phone", "email", "address", "city", "active"],
  suppliers: ["name", "phone", "address", "amountToReceive", "amountToPay", "active"],
  discounts: ["name", "description", "type", "value", "imageUrl", "isActive"],
  ingredients: ["name", "unit", "quantityInStock", "lowStockThreshold"],
  staff: ["name", "role", "dailyWage", "phone", "address", "active", "joinDate", "commissionRate", "showCommissionToStaff"],
  branches: ["name", "code", "address", "active"],
  expenses: ["category", "amount", "note"],
  purchases: ["supplierId", "supplierName", "date", "status", "itemsJson"],
  purchase_returns: ["originalPurchaseId", "supplierId", "supplierName", "reason", "itemsJson"],
  sale_returns: ["originalSaleId", "reason", "itemsJson"],
  store_out: ["reason", "handledBy", "date", "productsJson"],
  attendance: ["staffId", "date", "isPresent"],
};

function dateMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value < 1e12 ? value * 1000 : value;
  if (value && typeof value === "object" && "seconds" in value) return Number((value as {seconds:number}).seconds) * 1000;
  if (typeof value === "string" && value) { const parsed = new Date(value).getTime(); return Number.isFinite(parsed) ? parsed : null; }
  return null;
}

function display(value: unknown): string {
  if (value == null) return "—";
  if (typeof value === "object") {
    if ("seconds" in (value as object)) return new Date(Number((value as { seconds: number }).seconds) * 1000).toLocaleString();
    return JSON.stringify(value);
  }
  return typeof value === "number" ? value.toLocaleString("en-PK") : String(value);
}

export default function AdminWorkspace({ db, vendorId, moduleKey, onReprint, storage, actorName = "Next.js POS", actorId = vendorId, actorRole = "user", branchId = "", branchName = "" }: { db: Firestore; vendorId: string; moduleKey: ModuleKey; storage: FirebaseStorage | null; onReprint?:(row:Row)=>void; actorName?:string; actorId?:string; actorRole?:string; branchId?:string; branchName?:string }) {
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
  const [recipeMode,setRecipeMode] = useState(false);
  const [staffOptions, setStaffOptions] = useState<Row[]>([]);
  const [productOptions, setProductOptions] = useState<Row[]>([]);
  const [supplierOptions, setSupplierOptions] = useState<Row[]>([]);
  const [purchaseOptions, setPurchaseOptions] = useState<Row[]>([]);
  const [saleOptions, setSaleOptions] = useState<Row[]>([]);
  const [categoryOptions, setCategoryOptions] = useState<Row[]>([]);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [statusFilter, setStatusFilter] = useState("All");
  const [productStatusFilter, setProductStatusFilter] = useState("All");
  const [productCategoryFilter, setProductCategoryFilter] = useState("All");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const loadedPageCount = useRef(0);
  const firstPageIds = useRef<Set<string>>(new Set());

  useEffect(() => {
    setLoading(true);
    setError("");
    const ref = collection(db, "vendors", vendorId, config.collection);
    const paged = ["products", "purchases", "purchase_returns", "sale_returns", "sales", "expenses", "orders", "store_out"].includes(moduleKey);
    const orderField = moduleKey === "store_out" ? "date" : ["purchase_returns", "sale_returns", "sales", "expenses", "orders"].includes(moduleKey) ? "createdAt" : "createdOn";
    const firstQuery = paged ? query(ref, orderBy(orderField, "desc"), limit(20)) : query(ref, limit(250));
    setLastDoc(null); setHasMore(false); loadedPageCount.current = 0; firstPageIds.current = new Set();
    const stop = onSnapshot(firstQuery, snap => {
      const pageRows = snap.docs.map(d => ({ ...d.data(), id: d.id } as Row));
      if (paged && loadedPageCount.current > 0) {
        const previousFirstPageIds = firstPageIds.current;
        setRows(current => [...pageRows, ...current.filter(row => !previousFirstPageIds.has(row.id))]);
      } else setRows(pageRows);
      if (paged) firstPageIds.current = new Set(pageRows.map(row => row.id));
      if (paged && loadedPageCount.current === 0) { setLastDoc(snap.docs.length ? snap.docs[snap.docs.length - 1] : null); setHasMore(snap.docs.length === 20); }
      setLoading(false);
    }, err => {
      setError(err.message);
      setLoading(false);
    });
    return () => stop();
  }, [db, vendorId, config.collection]);

  useEffect(() => {
    if (moduleKey !== "attendance") { setStaffOptions([]); return; }
    const staffRef = collection(db, "vendors", vendorId, "staff");
    return onSnapshot(query(staffRef, limit(250)), snap => setStaffOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message));
  }, [db, vendorId, moduleKey]);

  useEffect(() => {
    if (moduleKey !== "products") { setCategoryOptions([]); return; }
    return onSnapshot(query(collection(db, "vendors", vendorId, "categories"), limit(300)), snap => setCategoryOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row)).filter(x => x.active !== false)), err => setError(err.message));
  }, [db, vendorId, moduleKey]);

  useEffect(() => {
    if (moduleKey === "sale_returns") {
      return onSnapshot(query(collection(db, "vendors", vendorId, "sales"), orderBy("createdAt", "desc"), limit(500)), snap => setSaleOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message));
    }
    setSaleOptions([]);
    if (!["purchases", "purchase_returns", "store_out"].includes(moduleKey)) { setProductOptions([]); setSupplierOptions([]); setPurchaseOptions([]); return; }
    const stops = [onSnapshot(query(collection(db, "vendors", vendorId, "products"), limit(500)), snap => setProductOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message))];
    if (["purchases", "purchase_returns"].includes(moduleKey)) stops.push(onSnapshot(query(collection(db, "vendors", vendorId, "suppliers"), limit(500)), snap => setSupplierOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message)));
    if (moduleKey === "purchase_returns") stops.push(onSnapshot(query(collection(db, "vendors", vendorId, "purchases"), limit(500)), snap => setPurchaseOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message)));
    return () => stops.forEach(stop => stop());
  }, [db, vendorId, moduleKey]);

  async function loadMore() {
    if (!hasMore || !lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const orderField = moduleKey === "store_out" ? "date" : ["purchase_returns", "sale_returns", "sales", "expenses", "orders"].includes(moduleKey) ? "createdAt" : "createdOn";
      const next = await getDocs(query(collection(db, "vendors", vendorId, config.collection), orderBy(orderField, "desc"), startAfter(lastDoc), limit(20)));
      loadedPageCount.current += 1;
      setRows(current => [...current, ...next.docs.map(d => ({ ...d.data(), id: d.id } as Row))]);
      setLastDoc(next.docs.length ? next.docs[next.docs.length - 1] : lastDoc);
      setHasMore(next.docs.length === 20);
    } catch (err) { setError(err instanceof Error ? err.message : "Unable to load more records."); }
    finally { setLoadingMore(false); }
  }

  const filtered = useMemo(() => rows.filter(row => {
    if (!JSON.stringify(row).toLowerCase().includes(search.toLowerCase())) return false;
    if ((moduleKey === "purchases" || moduleKey === "orders") && statusFilter !== "All" && String(row.status || (moduleKey==="purchases"?"Pending":"pending")) !== statusFilter) return false;
    if (moduleKey === "store_out" && row.active === false) return false;
    if (moduleKey === "products" && productStatusFilter !== "All" && (row.active === false ? "Inactive" : "Active") !== productStatusFilter) return false;
    if (moduleKey === "products" && productCategoryFilter !== "All" && String(row.category||"") !== productCategoryFilter) return false;
    if (moduleKey === "purchases" || moduleKey === "purchase_returns" || moduleKey === "sale_returns" || moduleKey === "sales" || moduleKey === "expenses" || moduleKey === "orders" || moduleKey === "store_out") {
      const millis = dateMillis(moduleKey === "purchases" || moduleKey === "store_out" ? row.date : row.createdAt);
      if (dateFrom && (millis == null || millis < new Date(dateFrom + "T00:00:00").getTime())) return false;
      if (dateTo && (millis == null || millis >= new Date(dateTo + "T00:00:00").getTime() + 86400000)) return false;
    }
    return true;
  }), [rows, search, moduleKey, statusFilter, productStatusFilter, productCategoryFilter, dateFrom, dateTo]);
  const total = useMemo(() => rows.reduce((sum, row) => {
    const amount = Number(row.total ?? row.amount ?? row.totalAmount ?? 0);
    return sum + (Number.isFinite(amount) ? amount : 0);
  }, 0), [rows]);

  function beginCreate() {
    setImageFile(null);
    setEditingId(null);
    setForm(moduleKey === "attendance" ? { date: new Date().toISOString().slice(0, 10), isPresent: "true" } : moduleKey === "purchases" ? { date: new Date().toISOString().slice(0, 10), status: "Pending", itemsJson: "[]" } : moduleKey === "purchase_returns" ? { itemsJson: "[]" } : moduleKey === "sale_returns" ? { itemsJson: "[]" } : {});
    setFormOpen(true);
  }

  function beginEdit(row: Row) {
    setImageFile(null);
    setEditingId(row.id);
    setForm(Object.fromEntries((fields[moduleKey] || []).map(field => [field, field === "variantsJson" ? JSON.stringify(row.variants || [], null, 2) : field === "attributesJson" ? JSON.stringify(row.attributes || [], null, 2) : field === "itemsJson" ? JSON.stringify(row.items || [], null, 2) : field === "productsJson" ? JSON.stringify(((row.products as Array<Record<string,unknown>>)||[]).map(item => ({productId:String(((item.product as Record<string,unknown>)?.id)||""),quantity:Number(item.quantity||0)})), null, 2) : field === "joinDate" ? String(row.joinDate || "").slice(0, 10) : field === "date" ? (row.date && typeof row.date === "object" && "seconds" in (row.date as object) ? new Date(Number((row.date as {seconds:number}).seconds)*1000).toISOString().slice(0,10) : String(row.date || "").slice(0,10)) : String(row[field] ?? "")])));
    setFormOpen(true);
  }

  function makePayload(now: Date): Record<string, unknown> {
    if (moduleKey === "products") {
      const parsed = form.variantsJson?.trim() ? JSON.parse(form.variantsJson) : [];
      let parsedAttributes: unknown; try { parsedAttributes = JSON.parse(form.attributesJson || "[]"); } catch { throw new Error("Attributes must be valid JSON."); }
      if (!Array.isArray(parsedAttributes) || parsedAttributes.some(a => !a || typeof a !== "object" || Array.isArray(a))) throw new Error("Attributes must be a JSON array of objects.");
      const attributes = (parsedAttributes as Array<Record<string, unknown>>).map(a => ({ id: String(a.id || crypto.randomUUID()), name: String(a.name || "").trim(), type: String(a.type || "text"), options: Array.isArray(a.options) ? a.options.map(String) : [], required: a.required === true }));
      if (attributes.some(a => !a.name)) throw new Error("Every product attribute needs a name.");
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
      if (variants.some(v => !Number.isFinite(v.priceModifier) || !Number.isInteger(v.quantity) || v.quantity < 0)) throw new Error("Variant price modifiers must be valid and stock quantities must be non-negative whole numbers.");
      const salePrice=Number(form.salePrice||0), purchasePrice=Number(form.purchasePrice||0), quantity=Number(form.quantity||0);
      if(!form.name?.trim() || !form.category?.trim()) throw new Error("Product name and category are required.");
      if(!Number.isFinite(salePrice)||salePrice<0||!Number.isFinite(purchasePrice)||purchasePrice<0||!Number.isInteger(quantity)||quantity<0) throw new Error("Prices must be non-negative and stock quantity must be a non-negative whole number.");
      return {
        name: form.name?.trim() || "", category: form.category || "", unit: form.unit || "piece",
        salePrice: Number(form.salePrice || 0), purchasePrice: Number(form.purchasePrice || 0),
        quantity: Number(form.quantity || 0), active: form.active !== "false", hasVariants: form.hasVariants === "true" || variants.length > 0, variants, attributes,
        imageUrl: form.imageUrl || "",
      };
    }
    if (moduleKey === "categories") { const name=form.name?.trim()||""; if(!name)throw new Error("Category name is required."); return { name, imageUrl: form.imageUrl || "", active: form.active!=="false" }; }
    if (moduleKey === "store_out") {
      if(!form.reason?.trim()||!form.handledBy?.trim())throw new Error("Reason and handler are required.");
      const date=new Date((form.date||new Date().toISOString().slice(0,10))+"T00:00:00");if(!Number.isFinite(date.getTime()))throw new Error("Choose a valid store-out date.");
      return {id:editingId||"",vendorId,reason:form.reason.trim(),handledBy:form.handledBy.trim(),date:Timestamp.fromDate(date),active:true,createdOn:editingId?(selected?.createdOn||Timestamp.fromDate(now)):Timestamp.fromDate(now)};
    }
    if (moduleKey === "sale_returns") {
      let parsed:unknown;try{parsed=JSON.parse(form.itemsJson||"[]")}catch{throw new Error("Return items must be valid JSON.")}
      if(!Array.isArray(parsed)||parsed.length===0)throw new Error("Select at least one item to return.");
      const items=parsed.map((v:Record<string,unknown>)=>{const returnedQuantity=Number(v.returnedQuantity||0),originalPrice=Number(v.originalPrice||0),refundAmount=Number(v.refundAmount??returnedQuantity*originalPrice);if(!v.productId||!v.productName||!Number.isInteger(returnedQuantity)||returnedQuantity<=0||!Number.isFinite(originalPrice)||originalPrice<0||!Number.isFinite(refundAmount)||refundAmount<0)throw new Error("Each return item needs productId, productName, positive returnedQuantity and valid price/refund.");return {productId:String(v.productId),productName:String(v.productName),originalPrice,returnedQuantity,refundAmount};});
      if(!form.originalSaleId?.trim()||!form.reason?.trim())throw new Error("Original sale and return reason are required.");
      const source=saleOptions.find(x=>x.id===form.originalSaleId);if(!source)throw new Error("The original sale could not be found. Refresh and select it again.");
      const sourceItems=Array.isArray(source.items)?source.items as Array<Record<string,unknown>>:[];
      for(const item of items){const sold=sourceItems.filter(x=>String(x.productId||x.id||"")===item.productId).reduce((sum,x)=>sum+Number(x.quantity||1),0);if(!sold||item.returnedQuantity>sold)throw new Error("Returned quantity cannot exceed the quantity recorded on the original sale for "+item.productName+".");}
      return {id:"",vendorId,originalSaleId:form.originalSaleId.trim(),items,totalRefund:items.reduce((sum,item)=>sum+item.refundAmount,0),reason:form.reason.trim(),createdAt:Date.now()};
    }
    if (moduleKey === "purchase_returns") {
      let parsed: unknown; try { parsed=JSON.parse(form.itemsJson||"[]"); } catch { throw new Error("Return items must be valid JSON."); }
      if(!Array.isArray(parsed)||parsed.length===0) throw new Error("Select at least one item to return.");
      const items=parsed.map((v:Record<string,unknown>)=>{const returnedQuantity=Number(v.returnedQuantity||0),originalPrice=Number(v.originalPrice||0),refundAmount=Number(v.refundAmount ?? returnedQuantity*originalPrice);if(!v.productId||!v.productName||!Number.isInteger(returnedQuantity)||returnedQuantity<=0||!Number.isFinite(originalPrice)||originalPrice<0||!Number.isFinite(refundAmount)||refundAmount<0)throw new Error("Each return item needs productId, productName, positive returnedQuantity and valid price/refund.");return {productId:String(v.productId),productName:String(v.productName),originalPrice,returnedQuantity,refundAmount};});
      if(!form.originalPurchaseId?.trim()||!form.supplierId?.trim()||!form.supplierName?.trim()||!form.reason?.trim())throw new Error("Original purchase, supplier and return reason are required.");
      const source=purchaseOptions.find(x=>x.id===form.originalPurchaseId);if(!source)throw new Error("The original purchase could not be found. Refresh and select it again.");
      const sourceItems=Array.isArray(source.items)?source.items as Array<Record<string,unknown>>:[];
      for(const item of items){const purchased=sourceItems.filter(x=>String(x.productId)===item.productId).reduce((sum,x)=>sum+Number(x.quantity||0),0);if(!purchased||item.returnedQuantity>purchased)throw new Error("Returned quantity cannot exceed the quantity recorded on the original purchase for "+item.productName+".");}
      if(String(source.supplierId||"")!==form.supplierId.trim())throw new Error("The selected supplier does not match the original purchase.");
      return {id:"",vendorId,originalPurchaseId:form.originalPurchaseId.trim(),supplierId:form.supplierId.trim(),supplierName:form.supplierName.trim(),items,totalRefund:items.reduce((sum,item)=>sum+item.refundAmount,0),reason:form.reason.trim(),createdAt:Timestamp.fromDate(now)};
    }
    if (moduleKey === "purchases") {
      let parsed: unknown;
      try { parsed = JSON.parse(form.itemsJson || "[]"); } catch { throw new Error("Purchase items must be valid JSON."); }
      if (!Array.isArray(parsed) || parsed.length === 0) throw new Error("Add at least one purchase item.");
      const items = parsed.map((v: Record<string, unknown>) => { const quantity=Number(v.quantity||0), unitPrice=Number(v.unitPrice||0); const product=productOptions.find(p=>p.id===String(v.productId||"")); if(!v.productId||!v.productName||!product||!Number.isInteger(quantity)||quantity<=0||!Number.isFinite(unitPrice)||unitPrice<0) throw new Error("Each item must reference an existing product and have a positive whole quantity and non-negative unit price."); if(v.variantId){const variants=Array.isArray(product.variants)?product.variants as Array<Record<string,unknown>>:[];if(!variants.some(x=>String(x.id)===String(v.variantId)))throw new Error("Selected product variant no longer exists.");} return {productId:String(v.productId),productName:String(v.productName),quantity,unitPrice,total:quantity*unitPrice,variantId:v.variantId?String(v.variantId):null,variantName:v.variantName?String(v.variantName):null}; });
      if(!form.supplierId?.trim()||!form.supplierName?.trim()) throw new Error("Select a supplier.");
      if(!["Pending", "Received", "Cancelled"].includes(form.status || "Pending")) throw new Error("Choose a valid purchase status.");
      const date=new Date((form.date||new Date().toISOString().slice(0,10))+"T00:00:00"); if(!Number.isFinite(date.getTime())) throw new Error("Choose a valid purchase date.");
      return {id:editingId||"",supplierId:form.supplierId.trim(),supplierName:form.supplierName.trim(),items,total:items.reduce((sum,item)=>sum+item.total,0),date:Timestamp.fromDate(date),status:form.status||"Pending",createdOn:editingId?(selected?.createdOn||Timestamp.fromDate(now)):Timestamp.fromDate(now)};
    }
    if (moduleKey === "attendance") {
      const staff = staffOptions.find(item => item.id === form.staffId);
      if (!staff) throw new Error("Select an active staff member.");
      const date = new Date((form.date || new Date().toISOString().slice(0, 10)) + "T00:00:00");
      if (!Number.isFinite(date.getTime())) throw new Error("Choose a valid attendance date.");
      return { id: "", vendorId, staffId: staff.id, staffName: String(staff.name || ""), dailyWage: Number(staff.dailyWage || 0), date: Timestamp.fromDate(date), isPresent: form.isPresent === "true", checkInTime: null, checkOutTime: null, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) };
    }
    if (moduleKey === "expenses") {
      const amount = Number(form.amount || 0);
      if (!Number.isFinite(amount) || amount <= 0) throw new Error("Expense amount must be greater than zero.");
      return { category: form.category || "General", amount, note: form.note?.trim() || "" };
    }
    if (moduleKey === "branches") { const name=form.name?.trim()||""; if(!name)throw new Error("Branch name is required."); return {name,code:form.code?.trim()||"",address:form.address?.trim()||"",active:form.active!=="false",premiumFeature:true}; }
    if (moduleKey === "staff") {
      const name = form.name?.trim() || "";
      const role = form.role?.trim() || "";
      if (!name || !role) throw new Error("Staff name and role are required.");
      if ((form.phone || "").replace(/\D/g, "").length < 8) throw new Error("Enter a valid staff phone number.");
      const joinDate = form.joinDate || new Date().toISOString().slice(0, 10);
      return { name, role, dailyWage: Math.max(0, Number(form.dailyWage || 0)), phone: form.phone || "", address: form.address || "", active: form.active !== "false", joinDate: new Date(joinDate + "T00:00:00").toISOString(), searchKeywords: Array.from(new Set([name.toLowerCase(), role.toLowerCase(), (form.phone || "").toLowerCase(), ...name.toLowerCase().split(" "), ...role.toLowerCase().split(" ")].filter(Boolean))), commissionRate: Math.max(0, Number(form.commissionRate || 0)), showCommissionToStaff: form.showCommissionToStaff === "true" };
    }
    if (moduleKey === "customers") {
      const name=form.name?.trim()||"", phone=form.phone||"", address=form.address?.trim()||"", email=form.email?.trim()||"";
      if(!name||!address)throw new Error("Customer name and address are required.");
      if(phone.replace(/\D/g,"").length<8)throw new Error("Enter a valid customer phone number.");
      if(email&&!/^[^@]+@[^@]+\.[^@]+$/.test(email))throw new Error("Enter a valid customer email.");
      return { name, phone, email: email||null, address, city: form.city?.trim()||null, active: form.active!=="false" };
    }
    if (moduleKey === "suppliers") {
      const name=form.name?.trim()||"", phone=form.phone||"", address=form.address?.trim()||"";
      const amountToReceive=Number(form.amountToReceive||0),amountToPay=Number(form.amountToPay||0);
      if(!name||!address)throw new Error("Supplier name and address are required.");
      if(phone.replace(/\D/g,"").length<8)throw new Error("Enter a valid supplier phone number.");
      if(!Number.isFinite(amountToReceive)||amountToReceive<0||!Number.isFinite(amountToPay)||amountToPay<0)throw new Error("Supplier balances must be non-negative amounts.");
      return { name, phone, address, amountToReceive, amountToPay, active: form.active!=="false" };
    }
    if (moduleKey === "discounts") { const name=form.name?.trim()||"",description=form.description?.trim()||"",type=form.type||"percentage",value=Number(form.value||0); if(!name||!description)throw new Error("Discount name and description are required."); if(!["percentage","fixed"].includes(type)||!Number.isFinite(value)||value<0)throw new Error("Choose a valid discount type and non-negative value."); if(type==="percentage"&&value>100)throw new Error("Percentage discount cannot exceed 100%."); return { name, description, type, value, imageUrl: form.imageUrl || "", isActive: form.isActive!=="false" }; }
    if (moduleKey === "ingredients") { const name=form.name?.trim()||"",unit=form.unit||"g",quantityInStock=Number(form.quantityInStock||0),lowStockThreshold=Number(form.lowStockThreshold||20); if(!name)throw new Error("Ingredient name is required."); if(!["g","kg","litre","piece","pack"].includes(unit))throw new Error("Choose a valid ingredient unit."); if(!Number.isFinite(quantityInStock)||quantityInStock<0||!Number.isFinite(lowStockThreshold)||lowStockThreshold<0)throw new Error("Ingredient stock and low-stock threshold must be non-negative numbers."); return {name,unit,quantityInStock,lowStockThreshold}; }
    return { name: form.name?.trim() || "", unit: form.unit || "g", quantityInStock: Number(form.quantityInStock || 0), lowStockThreshold: Number(form.lowStockThreshold || 20) };
  }

  async function saveRecord(e: React.FormEvent) {
    e.preventDefault();
    if (!canEdit || saving) return;
    setSaving(true);
    setError("");
    let recordId: string | null = editingId;
    try {
      if (imageFile) {
        if (!storage) throw new Error("Firebase Storage is not configured.");
        if (imageFile.size > 5 * 1024 * 1024) throw new Error("Image must be smaller than 5 MB.");
        if (!imageFile.type.startsWith("image/")) throw new Error("Choose a valid image file.");
      }
      const now = new Date();
      const payload = makePayload(now);
      const ref = collection(db, "vendors", vendorId, config.collection);
      if (moduleKey === "store_out") {
        let parsed:unknown;try{parsed=JSON.parse(form.productsJson||"[]")}catch{throw new Error("Store-out products must be valid JSON.")}
        if(!Array.isArray(parsed)||parsed.length===0)throw new Error("Add at least one product to store out.");
        const items=parsed.map((v:Record<string,unknown>)=>{const quantity=Number(v.quantity||0);if(!v.productId||!Number.isInteger(quantity)||quantity<=0)throw new Error("Each product requires a productId and positive integer quantity.");return {productId:String(v.productId),quantity};});
        const baseIds=Array.from(new Set(items.map(item=>item.productId.includes("_")?item.productId.split("_")[0]:item.productId)));
        const snaps=await Promise.all(baseIds.map(id=>getDoc(doc(db,"vendors",vendorId,"products",id))));
        const productsById=new Map<string,Record<string,unknown>>();const batch=writeBatch(db);
        for(let i=0;i<baseIds.length;i++){const snap=snaps[i];if(!snap.exists())throw new Error("Product not found: "+baseIds[i]);const data=snap.data()||{};let baseQtyDelta=0;const variantDeltas=new Map<string,number>();for(const item of items){const [baseId,variantId]=item.productId.split("_");if(baseId!==baseIds[i])continue;if(variantId)variantDeltas.set(variantId,(variantDeltas.get(variantId)||0)+item.quantity);else baseQtyDelta+=item.quantity;}
          const variants=Array.isArray(data.variants)?data.variants as Array<Record<string,unknown>>:[];
          for(const item of items){const [baseId,variantId]=item.productId.split("_");if(baseId!==baseIds[i]||!variantId)continue;const variant=variants.find(v=>String(v.id)===variantId);if(!variant)throw new Error("Variant not found: "+variantId);const available=Number(variant.quantity||0);if(!editingId && available<(variantDeltas.get(variantId)||0))throw new Error("Insufficient stock for "+String(data.name||baseId)+" - "+String(variant.name||variantId));productsById.set(item.productId,{...data,id:item.productId,name:String(data.name||"")+" - "+String(variant.name||""),salePrice:Number(data.salePrice||0)+Number(variant.priceModifier||0),quantity:available});}
          if(!editingId && baseQtyDelta>Number(data.quantity||0))throw new Error("Insufficient stock for "+String(data.name||baseIds[i]));
          const updatedVariants=variants.map(v=>variantDeltas.has(String(v.id))?{...v,quantity:Number(v.quantity||0)-(variantDeltas.get(String(v.id))||0)}:v);
          const patch:Record<string,unknown>={};if(baseQtyDelta)patch.quantity=Number(data.quantity||0)-baseQtyDelta;if(variantDeltas.size)patch.variants=updatedVariants;if(Object.keys(patch).length)batch.update(snap.ref,patch);
          productsById.set(baseIds[i],{...data,id:baseIds[i]});
        }
        const storeProducts=items.map(item=>({product:productsById.get(item.productId) || productsById.get(item.productId.split("_")[0]),quantity:item.quantity}));
        const storePayload={...payload,products:storeProducts};
        if(editingId){await updateDoc(doc(db,"vendors",vendorId,"store_outs",editingId),storePayload);}else{const created=doc(ref);batch.set(created,{...storePayload,id:created.id});await batch.commit();}
        setForm({});setEditingId(null);setFormOpen(false);return;
      }
      if (moduleKey === "purchase_returns" || moduleKey === "sale_returns") {
        const created=await addDoc(ref,payload);await updateDoc(created,{id:created.id});setForm({});setEditingId(null);setFormOpen(false);return;
      }
      if (moduleKey === "purchases") {
        const oldItems=editingId?((await getDoc(doc(db,"vendors",vendorId,"purchases",editingId))).data()?.items as Array<Record<string,unknown>>||[]):[];
        const newItems=payload.items as Array<Record<string,unknown>>;
        const ids=Array.from(new Set([...oldItems,...newItems].map(item=>String(item.productId))));
        const snaps=await Promise.all(ids.map(id=>getDoc(doc(db,"vendors",vendorId,"products",id))));
        const batch=writeBatch(db); const target=editingId?doc(db,"vendors",vendorId,"purchases",editingId):doc(ref);
        batch.set(target,{...payload,id:target.id});
        for(let i=0;i<ids.length;i++){const snap=snaps[i];if(!snap.exists())throw new Error("Cannot update purchase: product not found ("+ids[i]+").");const data=snap.data();const oldFor=oldItems.filter(item=>String(item.productId)===ids[i]);const newFor=newItems.filter(item=>String(item.productId)===ids[i]);const baseDelta=newFor.filter(item=>!item.variantId).reduce((s,item)=>s+Number(item.quantity||0),0)-oldFor.filter(item=>!item.variantId).reduce((s,item)=>s+Number(item.quantity||0),0);const vd=new Map<string,number>();for(const item of oldFor)if(item.variantId){const id=String(item.variantId);vd.set(id,(vd.get(id)||0)-Number(item.quantity||0));}for(const item of newFor)if(item.variantId){const id=String(item.variantId);vd.set(id,(vd.get(id)||0)+Number(item.quantity||0));}const patch:Record<string,unknown>={};if(baseDelta)patch.quantity=Number(data.quantity||0)+baseDelta;if(vd.size){const variants=Array.isArray(data.variants)?data.variants as Array<Record<string,unknown>>:[];for(const variantId of vd.keys())if(!variants.some(v=>String(v.id)===variantId))throw new Error("Purchase references a missing variant: "+variantId);patch.variants=variants.map(v=>vd.has(String(v.id))?{...v,quantity:Number(v.quantity||0)+(vd.get(String(v.id))||0)}:v);}if(Object.keys(patch).length)batch.update(snap.ref,patch);}
        await batch.commit();setForm({});setEditingId(null);setFormOpen(false);return;
      }
      if (moduleKey === "attendance") {
        const attendanceDate = new Date((form.date || now.toISOString().slice(0, 10)) + "T00:00:00");
        const dayEnd = new Date(attendanceDate); dayEnd.setHours(23, 59, 59, 999);
        const matches = await getDocs(query(ref, where("staffId", "==", payload.staffId), where("date", ">=", Timestamp.fromDate(attendanceDate)), where("date", "<=", Timestamp.fromDate(dayEnd)), limit(1)));
        if (matches.docs.length) await updateDoc(matches.docs[0].ref, { isPresent: payload.isPresent, updatedAt: Timestamp.fromDate(now) });
        else { const created = await addDoc(ref, payload); await updateDoc(created, { id: created.id }); }
        setForm({}); setEditingId(null); setFormOpen(false); return;
      }
      if (editingId) {
        const patch = moduleKey === "discounts"
          ? { ...payload, updatedAt: Timestamp.fromDate(now) }
          : payload;
        await updateDoc(doc(db, "vendors", vendorId, config.collection, editingId), patch);
      } else {
        let data: Record<string, unknown> = { ...payload };
        if (moduleKey === "products") data = { ...data, id: "", active: payload.active !== false, createdOn: now.toISOString() };
        if (moduleKey === "categories") data = { ...data, id: "", createdOn: editingId?(rows.find(row=>row.id===editingId)?.createdOn||now.toISOString()):now.toISOString() };
        if (moduleKey === "customers") data = { ...data, id: "", createdOn: Timestamp.fromDate(now), totalSpent: 0 };
        if (moduleKey === "expenses") data = { ...data, createdAt: serverTimestamp(), createdBy: actorName, createdById: actorId, branchId, branchName };
        if (moduleKey === "branches") data = { ...data, premiumFeature:true, createdAt:serverTimestamp() };
        if (moduleKey === "staff") data = { ...data, id: "", tipsEarned: 0, commissionEarned: 0, serviceChargesEarned: 0, pointsEarned: 0, averageRating: 0, reviewCount: 0, leakageTotal: 0, deductionsTotal: 0 };
        if (moduleKey === "suppliers") data = { ...data, id: "", createdOn: Timestamp.fromDate(now) };
        if (moduleKey === "discounts") data = { ...data, isActive: payload.isActive !== false, vendorId, createdAt: Timestamp.fromDate(now), updatedAt: Timestamp.fromDate(now) };
        if (moduleKey === "ingredients") data = { ...data, id: "", createdOn: now.toISOString() };
        const created = await addDoc(ref, data);
        recordId = created.id;
        if (moduleKey !== "discounts") await updateDoc(created, { id: created.id });
      }
      if (!imageFile && editingId && ["products", "categories", "discounts"].includes(moduleKey) && !String(payload.imageUrl || "") && storage) { const previous=rows.find(row=>row.id===editingId)?.imageUrl; if(typeof previous==="string" && previous){try{await deleteObject(storageRef(storage,previous));}catch{/* Removed image cleanup is best-effort. */}} }
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
      if (!editingId && recordId) setEditingId(recordId);
      setError(!editingId && recordId && imageFile ? "Record saved, but its image upload did not finish. Retry Save to complete the image upload." : err instanceof Error ? err.message : "Unable to save record.");
    } finally {
      setSaving(false);
    }
  }

  if (moduleKey === "dashboard") return <DashboardWorkspace db={db} vendorId={vendorId} actorId={actorId} actorRole={actorRole} actorName={actorName} branchName={branchName}/>;

  if (moduleKey === "attendance") return <AttendanceWorkspace db={db} vendorId={vendorId} staff={staffOptions}/>;
  if (moduleKey === "users_roles") return <UsersRolesWorkspace db={db} vendorId={vendorId} actorId={actorId} actorRole={actorRole}/>;
  if (moduleKey === "ingredients" && recipeMode) return <RecipeWorkspace db={db} vendorId={vendorId} onBack={()=>setRecipeMode(false)}/>;

  return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">MANAGEMENT</p><h1>{config.title}</h1><p className="muted">{config.description}</p></div><div className="admin-head-actions"><span className="count-badge">{rows.length} records</span>{moduleKey==="ingredients"&&<button className="secondary-btn" onClick={()=>setRecipeMode(true)}>Recipe assignment</button>}{canEdit && <button className="primary-btn" onClick={beginCreate}>+ Add new</button>}</div></div>
    {formOpen && <form className="admin-create-form" onSubmit={saveRecord}>
      <div className="record-detail-head"><strong>{editingId ? "Edit" : "New"} {config.title.replace(/s$/, "")}</strong><button type="button" className="icon-btn" onClick={() => { setFormOpen(false); setEditingId(null); }}>×</button></div>
      <div className="admin-form-grid">{(fields[moduleKey] || []).map(field => <label key={field}>{field.replace(/([A-Z])/g, " $1")}{field === "variantsJson" && moduleKey === "products" && <ProductVariantsEditor value={form[field] || "[]"} onChange={value=>setForm(v=>({...v,variantsJson:value}))}/>} {field === "attributesJson" && moduleKey === "products" && <ProductAttributesEditor value={form[field] || "[]"} onChange={value=>setForm(v=>({...v,attributesJson:value}))}/>}{field === "supplierId" && ["purchases", "purchase_returns"].includes(moduleKey) && <select required value={form.supplierId || ""} onChange={e => { const supplier=supplierOptions.find(x=>x.id===e.target.value); setForm(v=>({...v,supplierId:e.target.value,supplierName:String(supplier?.name||"")})); }}><option value="">Select supplier</option>{supplierOptions.filter(x=>x.active!==false).map(x=><option key={x.id} value={x.id}>{String(x.name||"Unnamed supplier")}</option>)}</select>}{field === "supplierName" && ["purchases", "purchase_returns"].includes(moduleKey) && <input readOnly required value={form.supplierName || ""} placeholder="Choose supplier above"/>}{field === "originalSaleId" && moduleKey === "sale_returns" && <select required value={form.originalSaleId || ""} onChange={e=>{const sale=saleOptions.find(x=>x.id===e.target.value);const items=Array.isArray(sale?.items)?sale.items as Array<Record<string,unknown>>:[];setForm(v=>({...v,originalSaleId:e.target.value,itemsJson:JSON.stringify(items.map(item=>{const productId=String(item.productId||item.id||"");const productName=String(item.productName||item.name||"Product");const quantity=Number(item.quantity||1);const originalPrice=Number(item.unitPrice??item.price??item.salePrice??0);return {productId,productName,returnedQuantity:quantity,originalPrice,refundAmount:quantity*originalPrice};}),null,2)}));}}><option value="">Select original sale</option>{saleOptions.map(x=><option key={x.id} value={x.id}>{String(x.tableNumber||"Sale")} · {x.id.slice(0,8)} · {display(x.total)}</option>)}</select>}{field === "originalPurchaseId" && moduleKey === "purchase_returns" && <select required value={form.originalPurchaseId || ""} onChange={e=>{const purchase=purchaseOptions.find(x=>x.id===e.target.value);const items=Array.isArray(purchase?.items)?purchase.items as Array<Record<string,unknown>>:[];setForm(v=>({...v,originalPurchaseId:e.target.value,supplierId:String(purchase?.supplierId||""),supplierName:String(purchase?.supplierName||""),itemsJson:JSON.stringify(items.map(item=>({productId:String(item.productId||""),productName:String(item.productName||""),returnedQuantity:Number(item.quantity||0),originalPrice:Number(item.unitPrice||0),refundAmount:Number(item.total||Number(item.quantity||0)*Number(item.unitPrice||0))})),null,2)}));}}><option value="">Select original purchase</option>{purchaseOptions.map(x=><option key={x.id} value={x.id}>{String(x.supplierName||"Supplier")} · {x.id.slice(0,8)} · {display(x.total)}</option>)}</select>}{!["variantsJson", "attributesJson"].includes(field) && !["active", "isActive", "showCommissionToStaff", "hasVariants", "category", "status", "type", "unit", "itemsJson", "productsJson", "supplierId", "supplierName", "originalPurchaseId", "imageUrl"].includes(field) && <input required={field === "name" || field === "role" || field === "amount" || (field === "phone" && moduleKey === "staff")} type={["value", "salePrice", "purchasePrice", "quantity", "quantityInStock", "lowStockThreshold", "dailyWage", "commissionRate", "amount", "amountToReceive", "amountToPay"].includes(field) ? "number" : ["joinDate", "date"].includes(field) ? "date" : "text"} step="any" value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}/>}{field === "hasVariants" && moduleKey === "products" && <select value={form.hasVariants || "false"} onChange={e=>setForm(v=>({...v,hasVariants:e.target.value,...(e.target.value==="false"?{variantsJson:"[]"}:{})}))}><option value="false">No variants</option><option value="true">Has variants</option></select>} {field === "category" && moduleKey === "products" && <select required value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option value="">Select category</option>{categoryOptions.map(x=><option key={x.id} value={String(x.name||"")}>{String(x.name||"")}</option>)}{form.category&&!categoryOptions.some(x=>String(x.name||"")===form.category)&&<option value={form.category}>{form.category} (current)</option>}{!categoryOptions.length&&!form.category&&<option value="General">General</option>}</select>} {field === "productsJson" && moduleKey === "store_out" && <StoreOutItemsEditor products={productOptions} value={form.productsJson||"[]"} onChange={value=>setForm(v=>({...v,productsJson:value}))}/>} {field === "itemsJson" && moduleKey === "purchases" && <PurchaseItemsEditor products={productOptions} value={form.itemsJson || "[]"} onChange={value=>setForm(v=>({...v,itemsJson:value}))}/>} {field === "itemsJson" && moduleKey === "purchase_returns" && <PurchaseReturnItemsEditor purchase={purchaseOptions.find(x=>x.id===form.originalPurchaseId)||null} value={form.itemsJson||"[]"} onChange={value=>setForm(v=>({...v,itemsJson:value}))}/>} {field === "itemsJson" && moduleKey === "sale_returns" && <SaleReturnItemsEditor sale={saleOptions.find(x=>x.id===form.originalSaleId)||null} value={form.itemsJson||"[]"} onChange={value=>setForm(v=>({...v,itemsJson:value}))}/>} {field === "unit" && moduleKey === "ingredients" && <select value={form.unit||"g"} onChange={e=>setForm(v=>({...v,unit:e.target.value}))}>{["g","kg","litre","piece","pack"].map(unit=><option key={unit}>{unit}</option>)}</select>}{field === "unit" && moduleKey === "products" && <input value={form.unit||"piece"} onChange={e=>setForm(v=>({...v,unit:e.target.value}))} placeholder="Unit"/>}{field === "type" && moduleKey === "discounts" && <select value={form.type || "percentage"} onChange={e=>setForm(v=>({...v,type:e.target.value}))}><option value="percentage">Percentage (%)</option><option value="fixed">Fixed amount</option></select>}{field === "status" && moduleKey === "purchases" && <select value={form[field] || "Pending"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option>Pending</option><option>Received</option><option>Cancelled</option></select>} {field === "category" && moduleKey === "expenses" && <select value={form[field] || "General"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}>{["General", "Salaries", "Rent", "Electricity", "Gas", "Maintenance", "Transport", "Marketing", "Purchases", "Other"].map(value => <option key={value}>{value}</option>)}</select>} {["active", "isActive", "showCommissionToStaff", "isPresent"].includes(field) && <select value={form[field] || (field === "active" || field === "isActive" ? "true" : "false")} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option value="true">{field === "isPresent" ? "Present" : "Active"}</option><option value="false">{field === "isPresent" ? "Absent" : "Inactive"}</option></select>}{field === "imageUrl" && ["products", "categories", "discounts"].includes(moduleKey) && <div className="image-field"><input type="file" accept="image/*" onChange={e => setImageFile(e.target.files?.[0] || null)}/>{form.imageUrl && <div className="image-preview"><img src={form.imageUrl} alt="Current image"/><button type="button" className="secondary-btn" onClick={()=>setForm(v=>({...v,imageUrl:""}))}>Remove image</button></div>}{imageFile&&<small>Selected: {imageFile.name}</small>}</div>}</label>)}</div>
      <button className="primary-btn" disabled={saving}>{saving ? "Saving…" : editingId ? "Update record" : "Save record"}</button>
    </form>}
    {["products", "purchases", "purchase_returns", "sale_returns", "sales", "expenses", "orders", "store_out"].includes(moduleKey) && <div className="record-filter-bar">{moduleKey === "products" && <><select aria-label="Product status filter" value={productStatusFilter} onChange={e=>setProductStatusFilter(e.target.value)}><option>All</option><option>Active</option><option>Inactive</option></select><select aria-label="Product category filter" value={productCategoryFilter} onChange={e=>setProductCategoryFilter(e.target.value)}><option>All</option>{Array.from(new Set([...categoryOptions.map(x=>String(x.name||"")),...rows.map(x=>String(x.category||""))].filter(Boolean))).sort().map(category=><option key={category}>{category}</option>)}</select></> }{moduleKey !== "products" && <>{moduleKey === "purchases" && <select aria-label="Purchase status filter" value={statusFilter} onChange={e=>setStatusFilter(e.target.value)}><option>All</option><option>Pending</option><option>Received</option><option>Cancelled</option></select>}{moduleKey === "orders" && <select aria-label="Order status filter" value={statusFilter} onChange={e=>setStatusFilter(e.target.value)}>{["All","pending","confirmed","completed","delivered","cancelled","rejected"].map(x=><option key={x}>{x}</option>)}</select>}<label>From <input aria-label="Filter from date" type="date" value={dateFrom} onChange={e=>setDateFrom(e.target.value)}/></label><label>To <input aria-label="Filter to date" type="date" value={dateTo} onChange={e=>setDateTo(e.target.value)}/></label></>}<button type="button" className="secondary-btn" onClick={()=>{setStatusFilter("All");setProductStatusFilter("All");setProductCategoryFilter("All");setDateFrom("");setDateTo("");}}>Reset filters</button></div>}
    <RecordsTable moduleKey={moduleKey} rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected} onLoadMore={loadMore} hasMore={hasMore} loadingMore={loadingMore} canEdit={canEdit && moduleKey !== "expenses" && moduleKey !== "purchase_returns" && moduleKey !== "sale_returns"} onEdit={beginEdit} onReprint={moduleKey==="sales"?onReprint:undefined} onOrderStatusChange={moduleKey==="orders"?async row=>{try{const deliveredAt=Date.now();await updateDoc(doc(db,"vendors",vendorId,"orders",row.id),{status:"completed",deliveredAt});const updated={...row,status:"completed",deliveredAt};setRows(current=>current.map(x=>x.id===row.id?updated:x));setSelected(updated);}catch(e){setError(e instanceof Error?e.message:"Unable to update order status.");}}:undefined} canDelete={moduleKey==="expenses" || moduleKey==="orders" || moduleKey==="staff" || moduleKey==="products" || moduleKey==="categories" || moduleKey==="discounts" || moduleKey==="ingredients" || moduleKey==="branches" || moduleKey==="purchases" || moduleKey==="store_out" || moduleKey==="customers" || moduleKey==="suppliers"} onDelete={moduleKey==="expenses" || moduleKey==="orders" || moduleKey==="staff" || moduleKey==="products" || moduleKey==="categories" || moduleKey==="discounts" || moduleKey==="ingredients" || moduleKey==="branches" || moduleKey==="purchases" || moduleKey==="store_out" || moduleKey==="customers" || moduleKey==="suppliers"?async row=>{const label=({staff:"employee",orders:"order",products:"product",categories:"category",discounts:"discount",ingredients:"ingredient",branches:"branch",purchases:"purchase",store_out:"store movement",customers:"customer",suppliers:"supplier",expenses:"expense"} as Record<string,string>)[moduleKey]||"record";if(!window.confirm(`Delete this ${label} record${moduleKey==="staff" && row.name?` for ${String(row.name)}`:""}?`))return;try{if(moduleKey==="purchases"){const items=Array.isArray(row.items)?row.items as Array<Record<string,unknown>>:[];const ids=Array.from(new Set(items.map(item=>String(item.productId))));const snaps=await Promise.all(ids.map(id=>getDoc(doc(db,"vendors",vendorId,"products",id))));const batch=writeBatch(db);for(let i=0;i<ids.length;i++){if(!snaps[i].exists())continue;const data=snaps[i].data() || {};const selectedItems=items.filter(item=>String(item.productId)===ids[i]);const base=selectedItems.filter(item=>!item.variantId).reduce((s,item)=>s+Number(item.quantity||0),0);const vd=new Map<string,number>();for(const item of selectedItems)if(item.variantId){const id=String(item.variantId);vd.set(id,(vd.get(id)||0)+Number(item.quantity||0));}const patch:Record<string,unknown>={};if(base)patch.quantity=Number(data.quantity||0)-base;if(vd.size)patch.variants=(Array.isArray(data.variants)?data.variants:[]).map((v:Record<string,unknown>)=>vd.has(String(v.id))?{...v,quantity:Number(v.quantity||0)-(vd.get(String(v.id))||0)}:v);if(Object.keys(patch).length)batch.update(snaps[i].ref,patch);}batch.delete(doc(db,"vendors",vendorId,"purchases",row.id));await batch.commit();}else if(["products","categories","discounts"].includes(moduleKey)){await deleteDoc(doc(db,"vendors",vendorId,config.collection,row.id));if(storage && typeof row.imageUrl==="string" && row.imageUrl){try{await deleteObject(storageRef(storage,row.imageUrl));}catch{/* Storage cleanup is best-effort after catalog deletion. */}}}else if(moduleKey==="store_out") await updateDoc(doc(db,"vendors",vendorId,"store_outs",row.id),{active:false});else { await deleteDoc(doc(db,"vendors",vendorId,config.collection,row.id)); }setSelected(null)}catch(err){setError(err instanceof Error?err.message:`Unable to delete ${label}.`)}}:undefined}/>
    <p className="admin-note"><FileText size={17}/> This module is a migration slice. Unsupported workflow side effects, permissions and validations are not simulated here.</p>
  </section>;
}

function RecordsTable({ moduleKey, rows, loading, error, search, setSearch, selected, setSelected, canEdit = false, onEdit, onReprint, onOrderStatusChange, canDelete = false, onDelete, onLoadMore, hasMore = false, loadingMore = false }: {
  moduleKey?: ModuleKey; rows: Row[]; loading: boolean; error: string; search: string; setSearch: (s: string) => void;
  selected: Row | null; setSelected: (r: Row | null) => void; canEdit?: boolean; onEdit?: (r: Row) => void; onReprint?:(r:Row)=>void; onOrderStatusChange?:(r:Row)=>void; canDelete?: boolean; onDelete?: (r:Row)=>void; onLoadMore?:()=>void; hasMore?:boolean; loadingMore?:boolean;
}) {
  const keys = useMemo(() => {
    const preferred = moduleKey === "products" ? ["name", "imageUrl", "category", "unit", "salePrice", "quantity", "hasVariants", "active"] : moduleKey === "branches" ? ["name", "code", "address", "active"] : moduleKey === "ingredients" ? ["name", "unit", "quantityInStock", "lowStockThreshold"] : moduleKey === "discounts" ? ["name", "type", "value", "isActive", "updatedAt"] : moduleKey === "categories" ? ["name", "imageUrl", "active"] : moduleKey === "customers" ? ["name", "phone", "email", "city", "active", "totalSpent"] : moduleKey === "suppliers" ? ["name", "phone", "address", "amountToReceive", "amountToPay", "active"] : moduleKey === "purchase_returns" ? ["supplierName", "originalPurchaseId", "totalRefund", "reason", "createdAt"] : moduleKey === "sale_returns" ? ["originalSaleId", "totalRefund", "reason", "createdAt"] : moduleKey === "sales" ? ["tableNumber", "total", "paymentMethod", "waiterName", "createdAt"] : moduleKey === "expenses" ? ["category", "amount", "note", "createdBy", "createdAt"] : moduleKey === "store_out" ? ["reason", "handledBy", "date", "active"] : moduleKey === "orders" ? ["status", "totalAmount", "paymentMethod", "createdAt"] : ["supplierName", "status", "total", "date", "createdOn"];
    const all = Array.from(new Set(rows.flatMap(r => Object.keys(r).filter(k => k !== "id"))));
    return [...preferred.filter(k => all.includes(k)), ...all.filter(k => !preferred.includes(k))].slice(0, moduleKey === "products" ? 8 : 6);
  }, [rows]);
  return <>
    <div className="admin-toolbar"><div className="search-wrap"><Search size={17}/><input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search records…"/></div><button className="secondary-btn" onClick={() => setSearch("")}><RefreshCw size={15}/> Clear</button></div>
    {error && <p className="error-text">{error}</p>}
    {loading ? <div className="empty-state">Loading records…</div> : !rows.length ? <div className="empty-state">No records found in this collection.</div> : <div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Document ID</th>{keys.map(k => <th key={k}>{k}</th>)}</tr></thead><tbody>{rows.map(row => <tr key={row.id} onClick={() => setSelected(row)}><td><button className="record-link">{row.id}</button></td>{keys.map(k => <td key={k}>{moduleKey==="products"&&k==="imageUrl"&&typeof row.imageUrl==="string"&&row.imageUrl?<img className="table-product-image" src={row.imageUrl} alt={String(row.name||"Product")}/>:moduleKey==="products"&&k==="quantity"?(()=>{const stock=row.hasVariants&&Array.isArray(row.variants)?(row.variants as Array<Record<string,unknown>>).reduce((sum,v)=>sum+Number(v.quantity||0),0):Number(row.quantity||0);return <span className={stock<20?"stock-warning":""}>{stock.toLocaleString("en-PK")}{stock<20&&<small>Low stock</small>}</span>;})():moduleKey==="products"&&k==="salePrice"?(()=>{const variants=Array.isArray(row.variants)?(row.variants as Array<Record<string,unknown>>).filter(v=>v.active!==false):[];const prices=variants.map(v=>Number(row.salePrice||0)+Number(v.priceModifier||0)).filter(Number.isFinite);return (prices.length?Math.min(...prices):Number(row.salePrice||0)).toLocaleString("en-PK");})():moduleKey==="products"&&k==="hasVariants"?(Array.isArray(row.variants)&&row.variants.length?`${row.variants.length} variants`:"No variants"):moduleKey==="products"&&k==="active"?(row.active===false?"Inactive":"Active"):display(row[k])}</td>)}</tr>)}</tbody></table></div>}
    {selected && <div className="record-detail"><div className="record-detail-head"><strong>{moduleKey==="purchase_returns"?"Purchase return details":moduleKey==="sale_returns"?"Sale return details":moduleKey==="purchases"?"Purchase details":moduleKey==="sales"?"Sale details":moduleKey==="expenses"?"Expense details":moduleKey==="orders"?"Order details":moduleKey==="store_out"?"Store-out details":moduleKey==="products"?"Product details":"Record details"}</strong><div className="record-actions">{canEdit && onEdit && <button className="secondary-btn" onClick={() => onEdit(selected)}>Edit record</button>}{canDelete && onDelete && <button className="secondary-btn danger-btn" onClick={() => onDelete(selected)}>Delete record</button>}{onReprint&&<button className="secondary-btn" onClick={()=>onReprint(selected)}>Reprint receipt</button>}{moduleKey==="orders"&&onOrderStatusChange&&!["completed","delivered"].includes(String(selected.status||"").toLowerCase())&&<button className="secondary-btn" onClick={()=>onOrderStatusChange(selected)}>Mark completed</button>}<button className="icon-btn" onClick={() => setSelected(null)}>×</button></div></div>{["purchases","purchase_returns","sale_returns"].includes(moduleKey||"") ? <>{moduleKey==="purchases"||moduleKey==="purchase_returns"?<p><b>Supplier:</b> {String(selected.supplierName||"—")}</p>:null}<p><b>{moduleKey==="purchases"?"Purchase":moduleKey==="purchase_returns"?"Original purchase":"Original sale"}:</b> {String(moduleKey==="purchases"?selected.id:moduleKey==="purchase_returns"?selected.originalPurchaseId||"—":selected.originalSaleId||"—")}</p><p><b>Total:</b> {display(moduleKey==="purchases"?selected.total:selected.totalRefund)}</p><p><b>{moduleKey==="purchases"?"Status":"Reason"}:</b> {String(moduleKey==="purchases"?selected.status:selected.reason||"—")}</p><div className="admin-table-wrap"><table className="admin-table"><thead><tr>{(moduleKey==="purchases"?["Product","Qty","Unit price","Line total"]:["Product","Original price","Qty returned","Refund"]).map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{(Array.isArray(selected.items)?selected.items as Array<Record<string,unknown>>:[]).map((item,i)=><tr key={i}><td>{String(item.productName||"—")}</td><td>{moduleKey==="purchases"?Number(item.quantity||0):display(item.originalPrice)}</td><td>{moduleKey==="purchases"?display(item.unitPrice):Number(item.returnedQuantity||0)}</td><td>{display(moduleKey==="purchases"?item.total:item.refundAmount)}</td></tr>)}</tbody></table></div></>:moduleKey==="store_out"?<><p><b>Reason:</b> {String(selected.reason||"—")}</p><p><b>Handled by:</b> {String(selected.handledBy||"—")}</p><p><b>Date:</b> {display(selected.date)}</p><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Product</th><th>Qty</th><th>Unit value</th></tr></thead><tbody>{(Array.isArray(selected.products)?selected.products as Array<Record<string,unknown>>:[]).map((entry,i)=>{const product=entry.product&&typeof entry.product==="object"?entry.product as Record<string,unknown>:{};return <tr key={i}><td>{String(product.name||"—")}</td><td>{Number(entry.quantity||0)}</td><td>{display(product.salePrice)}</td></tr>;})}</tbody></table></div></>:moduleKey==="orders"?<><p><b>Order ID:</b> {String(selected.id)}</p><p><b>Status:</b> {String(selected.status||"pending")}</p><p><b>Payment:</b> {String(selected.paymentMethod||"Cash on Delivery")}</p><p><b>Subtotal / delivery fee:</b> {display(selected.subtotal)} / {display(selected.deliveryFee)}</p><p><b>Total:</b> {display(selected.totalAmount)}</p><p><b>Delivered:</b> {selected.deliveredAt?new Date(Number(selected.deliveredAt)).toLocaleString():"—"}</p><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Product</th><th>Variant</th><th>Qty</th><th>Price</th><th>Subtotal</th></tr></thead><tbody>{(Array.isArray(selected.items)?selected.items as Array<Record<string,unknown>>:[]).map((item,i)=><tr key={i}><td>{String(item.productName||"—")}</td><td>{String(item.selectedVariantName||"Standard")}</td><td>{Number(item.quantity||0)}</td><td>{display(item.price)}</td><td>{display(item.totalPrice)}</td></tr>)}</tbody></table></div></>:moduleKey==="expenses"?<><p><b>Category:</b> {String(selected.category||"General")}</p><p><b>Amount:</b> {display(selected.amount)}</p><p><b>Note:</b> {String(selected.note||"—")}</p><p><b>Recorded by:</b> {String(selected.createdBy||"—")}</p><p><b>Branch:</b> {String(selected.branchName||"—")}</p></>:moduleKey==="sales"?<><p><b>Receipt:</b> {String(selected.id)}</p><p><b>Total:</b> {display(selected.total)}</p><p><b>Payment:</b> {String(selected.paymentMethod||"Cash")}{selected.paymentReference?" · "+String(selected.paymentReference):""}</p><p><b>Table:</b> {String(selected.tableNumber||"Quick sale")}</p><p><b>Waiter:</b> {String(selected.waiterName||"—")}</p><p><b>Tips / service charge:</b> {display(selected.tipAmount)} / {display(selected.serviceChargeAmount)}</p><p><b>Receipt prints:</b> {display(selected.receiptPrintCount)}</p><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Product</th><th>Qty</th><th>Unit price</th><th>Line total</th></tr></thead><tbody>{(Array.isArray(selected.items)?selected.items as Array<Record<string,unknown>>:[]).map((item,i)=><tr key={i}><td>{String(item.productName||"—")}</td><td>{Number(item.quantity||0)}</td><td>{display(item.price)}</td><td>{display(Number(item.price||0)*Number(item.quantity||0))}</td></tr>)}</tbody></table></div></>:moduleKey==="products"?<><div className="product-detail-summary">{typeof selected.imageUrl === "string" && selected.imageUrl.length > 0 && <img className="detail-product-image" src={selected.imageUrl} alt={String(selected.name||"Product")}/>}<div><p><b>Category:</b> {String(selected.category||"—")}</p><p><b>Unit:</b> {String(selected.unit||"—")}</p><p><b>Sale price:</b> {display(selected.salePrice)}</p><p><b>Purchase price:</b> {display(selected.purchasePrice)}</p><p><b>Stock:</b> {display(selected.quantity)}{selected.hasVariants?" (base stock; see variants)":""}</p><p><b>Status:</b> {selected.active===false?"Inactive":"Active"}</p></div></div>{Array.isArray(selected.variants)&&selected.variants.length>0&&<><h4>Variants</h4><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Variant</th><th>Price modifier</th><th>Stock</th><th>Status</th></tr></thead><tbody>{(selected.variants as Array<Record<string,unknown>>).map((v,i)=><tr key={String(v.id||i)}><td>{String(v.name||"—")}</td><td>{display(v.priceModifier)}</td><td>{display(v.quantity)}</td><td>{v.active===false?"Inactive":"Active"}</td></tr>)}</tbody></table></div></>}{Array.isArray(selected.attributes)&&selected.attributes.length>0&&<><h4>Product attributes</h4><ul>{(selected.attributes as Array<Record<string,unknown>>).map((a,i)=><li key={String(a.id||i)}>{String(a.name||"")} · {String(a.type||"text")}{a.required?" · Required":""}{Array.isArray(a.options)&&a.options.length?" · "+a.options.map(String).join(", "):""}</li>)}</ul></>}</>:null}<pre>{JSON.stringify(selected, null, 2)}</pre></div>}
    {onLoadMore && hasMore && <div className="load-more-row"><button className="secondary-btn" onClick={onLoadMore} disabled={loadingMore}>{loadingMore?"Loading…":"Load more records"}</button></div>}
  </>;
}






function DashboardWorkspace({db,vendorId,actorId,actorRole,actorName,branchName}:{db:Firestore;vendorId:string;actorId:string;actorRole:string;actorName:string;branchName:string}) {
  const [sales,setSales]=useState<Row[]>([]);const [tables,setTables]=useState<Row[]>([]);const [tableOrders,setTableOrders]=useState<Row[]>([]);const [products,setProducts]=useState<Row[]>([]);const [branches,setBranches]=useState<Row[]>([]);const [owner,setOwner]=useState<Row>({id:""});
  const [error,setError]=useState("");
  useEffect(()=>{
    const stops=[
      onSnapshot(query(collection(db,"vendors",vendorId,"sales"),orderBy("createdAt","desc"),limit(500)),snap=>setSales(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),e=>setError(e.message)),
      onSnapshot(collection(db,"vendors",vendorId,"tables"),snap=>setTables(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),e=>setError(e.message)),
      onSnapshot(collection(db,"vendors",vendorId,"tableOrders"),snap=>setTableOrders(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),e=>setError(e.message)),
      onSnapshot(query(collection(db,"vendors",vendorId,"products"),limit(500)),snap=>setProducts(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),e=>setError(e.message)),
      onSnapshot(collection(db,"vendors",vendorId,"branches"),snap=>setBranches(snap.docs.map(d=>({...d.data(),id:d.id} as Row)).filter(x=>x.active!==false)),e=>setError(e.message)),
    ];
    getDoc(doc(db,"vendors",vendorId)).then(snap=>setOwner({...snap.data(),id:snap.id} as Row)).catch(e=>setError(e.message));
    return ()=>stops.forEach(stop=>stop());
  },[db,vendorId]);
  if(!["admin","superAdmin","super_admin","auditor"].includes(actorRole))return <EmployeeDashboardWorkspace db={db} vendorId={vendorId} actorId={actorId} actorName={actorName} actorRole={actorRole} branchName={branchName}/>;
  const now=new Date();const startToday=new Date(now.getFullYear(),now.getMonth(),now.getDate()).getTime();
  const todaySales=sales.filter(x=>(dateMillis(x.createdAt)||0)>=startToday);
  const todayRevenue=todaySales.reduce((sum,x)=>sum+Number(x.total||0),0);
  const avgBill=todaySales.length?todayRevenue/todaySales.length:0;
  const activeTables=tables.filter(x=>String(x.status||"empty").toLowerCase()!=="empty").length;
  const praFinalized=todaySales.filter(x=>String(x.praInvoiceNo||"").trim()).length;
  const kotCounts={open:0,making:0,ready:0,served:0};
  for(const order of tableOrders){const status=String(order.status||"open").toLowerCase();if(status in kotCounts)(kotCounts as Record<string,number>)[status]++;}
  const days=Array.from({length:7},(_,i)=>{const date=new Date(now.getFullYear(),now.getMonth(),now.getDate()-6+i);const key=date.getTime();const next=key+86400000;const value=sales.filter(x=>{const t=dateMillis(x.createdAt)||0;return t>=key&&t<next;}).reduce((sum,x)=>sum+Number(x.total||0),0);return {date,label:date.toLocaleDateString("en-PK",{weekday:"short"}),value};});
  const maxRevenue=Math.max(1,...days.map(x=>x.value));
  const weekStart=new Date(now.getFullYear(),now.getMonth(),now.getDate()-6).getTime();
  const itemTotals=new Map<string,{quantity:number;revenue:number}>();
  for(const sale of sales){if((dateMillis(sale.createdAt)||0)<weekStart)continue;for(const item of Array.isArray(sale.items)?sale.items as Array<Record<string,unknown>>:[]){const name=String(item.productName||"Item"),current=itemTotals.get(name)||{quantity:0,revenue:0};current.quantity+=Number(item.quantity||0);current.revenue+=Number(item.price||0)*Number(item.quantity||0);itemTotals.set(name,current);}}
  const topItems=Array.from(itemTotals.entries()).sort((a,b)=>b[1].quantity-a[1].quantity).slice(0,5);
  const lowStock=products.flatMap(p=>{if(p.active===false)return[];if(p.hasVariants===true&&Array.isArray(p.variants)){return (p.variants as Array<Record<string,unknown>>).filter(v=>v.active!==false&&Number(v.quantity||0)<=Number(p.lowStockThreshold||5)).map(v=>({id:String(p.id)+"_"+String(v.id),name:String(p.name||"Product")+" - "+String(v.name||"Variant"),quantity:Number(v.quantity||0),threshold:Number(p.lowStockThreshold||5)}));}const quantity=Number(p.quantity||0),threshold=Number(p.lowStockThreshold||5);return quantity<=threshold?[{id:p.id,name:String(p.name||"Product"),quantity,threshold}]:[];}).slice(0,8);
  const recent=sales.slice(0,8);
  return <section className="admin-module"><div className="section-head"><div><p className="eyebrow">BUSINESS OVERVIEW</p><h1>Dashboard</h1><p className="muted">{String(owner.restaurantName||"Restaurant")} · Live operational metrics</p></div><span className="live-pill"><span/> Live</span></div>{error&&<p className="error-text">{error}</p>}
    <div className="admin-kpis"><article><small>Today's sales</small><strong>{display(todayRevenue)}</strong></article><article><small>Receipts today</small><strong>{todaySales.length}</strong></article><article><small>Average bill</small><strong>{display(avgBill)}</strong></article><article><small>Active tables</small><strong>{activeTables} / {tables.length}</strong></article><article><small>PRA finalized</small><strong>{praFinalized} / {todaySales.length}</strong></article><article><small>Low-stock alerts</small><strong>{lowStock.length}</strong></article></div>
    <div className="dashboard-grid"><section className="dashboard-panel"><div className="record-detail-head"><strong>Sales overview · last 7 days</strong><span className="muted">PKR</span></div><div className="dashboard-bars">{days.map(day=><div className="dashboard-bar-item" key={day.date.toISOString()}><div className="dashboard-bar-track"><div className="dashboard-bar-fill" style={{height:Math.max(3,(day.value/maxRevenue)*100)+"%"}}/></div><strong>{day.value.toLocaleString("en-PK",{maximumFractionDigits:0})}</strong><small>{day.label}</small></div>)}</div></section>
    <section className="dashboard-panel"><div className="record-detail-head"><strong>Kitchen queue</strong><span className="muted">{tableOrders.length} live orders</span></div><div className="dashboard-kot-grid">{Object.entries(kotCounts).map(([status,count])=><div key={status}><small>{status}</small><strong>{count}</strong></div>)}</div></section>
    <section className="dashboard-panel"><div className="record-detail-head"><strong>Top selling items</strong><span className="muted">7 days</span></div>{topItems.length?topItems.map(([name,data])=><div className="dashboard-list-row" key={name}><span>{name}</span><strong>{data.quantity} sold</strong><small>{display(data.revenue)}</small></div>):<p className="muted">No sales in the last 7 days.</p>}</section>
    <section className="dashboard-panel"><div className="record-detail-head"><strong>Low-stock alerts</strong><span className="count-badge">{lowStock.length}</span></div>{lowStock.length?lowStock.map(item=><div className="dashboard-list-row" key={item.id}><span>{item.name}</span><strong>{item.quantity} left</strong><small>Threshold {item.threshold}</small></div>):<p className="muted">No low-stock items.</p>}</section>
    <section className="dashboard-panel dashboard-wide"><div className="record-detail-head"><strong>Recent sales</strong><span className="muted">Latest 8 receipts</span></div><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Receipt</th><th>Time</th><th>Table</th><th>Payment</th><th>Total</th></tr></thead><tbody>{recent.map(sale=><tr key={sale.id}><td>{sale.id}</td><td>{display(sale.createdAt)}</td><td>{String(sale.tableNumber||"Quick sale")}</td><td>{String(sale.paymentMethod||"—")}</td><td>{display(sale.total)}</td></tr>)}{!recent.length&&<tr><td colSpan={5}>No sales recorded yet.</td></tr>}</tbody></table></div></section>
    <section className="dashboard-panel"><div className="record-detail-head"><strong>Branches</strong><span className="muted">{branches.length+1} locations</span></div><div className="dashboard-list-row"><span>{String(owner.branchName||"Main Branch")}</span><strong>Main</strong><small>{String(owner.location||"")}</small></div>{branches.map(b=><div className="dashboard-list-row" key={b.id}><span>{String(b.name||"Branch")}</span><strong>{String(b.code||"")}</strong><small>{String(b.address||"")}</small></div>)}</section></div>
    <p className="admin-note"><Database size={18}/> Metrics are calculated from the live Firestore sales, table, KOT, product and branch records. Sales are limited to the latest 500 receipts for this dashboard view.</p>
  </section>;
}


function EmployeeDashboardWorkspace({db,vendorId,actorId,actorName,actorRole,branchName}:{db:Firestore;vendorId:string;actorId:string;actorName:string;actorRole:string;branchName:string}) {
  const [staff,setStaff]=useState<Row>({id:actorId});const [attendance,setAttendance]=useState<Row|null>(null);const [error,setError]=useState("");
  useEffect(()=>{
    const start=new Date();start.setHours(0,0,0,0);const end=new Date(start);end.setDate(end.getDate()+1);
    const stops=[
      onSnapshot(doc(db,"vendors",vendorId,"staff",actorId),snap=>setStaff({...snap.data(),id:snap.id} as Row),e=>setError(e.message)),
      onSnapshot(query(collection(db,"vendors",vendorId,"attendance"),where("staffId","==",actorId),where("date",">=",Timestamp.fromDate(start)),where("date","<",Timestamp.fromDate(end)),limit(1)),snap=>setAttendance(snap.empty?null:{...snap.docs[0].data(),id:snap.docs[0].id} as Row),e=>setError(e.message)),
    ];return ()=>stops.forEach(stop=>stop());
  },[db,vendorId,actorId]);
  const start=dateMillis(attendance?.checkInTime),end=dateMillis(attendance?.checkOutTime);
  const workedHours=start!==null&&end!==null&&end>=start?(end-start)/3600000:null;
  const showCommission=staff.showCommissionToStaff===true;
  const metrics=[{label:"My tips",value:display(staff.tipsEarned)},{label:"Service charges",value:display(staff.serviceChargesEarned)},{label:"My points",value:display(staff.pointsEarned)},{label:"Customer rating",value:Number(staff.averageRating||0).toFixed(1)},{label:"Customer reviews",value:display(staff.reviewCount)}];
  if(showCommission)metrics.splice(2,0,{label:"My commission",value:display(staff.commissionEarned)});
  return <section className="admin-module"><div className="section-head"><div><p className="eyebrow">MY WORKSPACE</p><h1>{actorRole.replaceAll("_"," ").replace(/\b\w/g,c=>c.toUpperCase())} dashboard</h1><p className="muted">{actorName} · {branchName||"Main Branch"}</p></div><span className="live-pill"><span/> Live</span></div>{error&&<p className="error-text">{error}</p>}
    <div className="dashboard-panel"><div className="record-detail-head"><strong>My profile</strong></div><div className="dashboard-list-row"><span>Name</span><strong>{String(staff.name||actorName)}</strong></div><div className="dashboard-list-row"><span>Department</span><strong>{String(staff.role||actorRole)}</strong></div><div className="dashboard-list-row"><span>Attendance today</span><strong>{attendance?(attendance.isPresent===true?"Present":"Absent"):"Not marked"}</strong></div><div className="dashboard-list-row"><span>Worked today</span><strong>{workedHours===null?"—":workedHours.toFixed(1)+" hours"}</strong></div></div>
    <div className="admin-kpis">{metrics.map(metric=><article key={metric.label}><small>{metric.label}</small><strong>{metric.value}</strong></article>)}</div>
    <p className="admin-note">Only your own staff profile and attendance information are shown in this role-based dashboard.</p>
  </section>;
}

const departmentRolePresets = [
  {role:"admin",label:"Restaurant Admin",department:"Administration",permissions:["dashboard.view","tables.manage","orders.manage","billing.manage","inventory.manage","customers.manage","purchases.manage","suppliers.manage","recipes.manage","reports.view","users.manage","settings.manage"]},
  {role:"manager",label:"Manager",department:"Management",permissions:["dashboard.view","tables.manage","orders.manage","billing.manage","inventory.view","customers.view","reports.view"]},
  {role:"cashier",label:"Cashier / POS Operator",department:"Cash Counter",permissions:["tables.view","tables.open","orders.create","orders.edit","kot.send","billing.create","payments.receive","receipts.print","sales.own_shift"]},
  {role:"waiter",label:"Waiter / Server",department:"Service",permissions:["tables.view","tables.open","orders.create","orders.edit","kot.send","bill.request"]},
  {role:"kitchen",label:"Kitchen / KDS",department:"Kitchen",permissions:["kot.view","kot.accept","kot.making","kot.ready"]},
  {role:"operations",label:"Operations",department:"Operations",permissions:["tables.view","orders.view","inventory.manage","purchases.manage","suppliers.manage","recipes.manage"]},
  {role:"accounts",label:"Accounts",department:"Accounts",permissions:["sales.view","purchases.view","expenses.manage","supplier_ledger.view","returns.manage","reports.financial"]},
  {role:"inventory",label:"Inventory / Store Keeper",department:"Store",permissions:["inventory.manage","stock.receive","stock.adjust","wastage.manage","suppliers.view"]},
  {role:"delivery",label:"Delivery / Dispatcher",department:"Delivery",permissions:["delivery.orders","customers.delivery","delivery.assign","delivery.status"]},
  {role:"reception",label:"Reception / Host",department:"Front Desk",permissions:["tables.view","reservations.manage","waitlist.manage"]},
  {role:"auditor",label:"Owner / Auditor",department:"Audit",permissions:["dashboard.view","sales.view","inventory.view","accounts.view","reports.view","audit.view"]},
] as const;

function UsersRolesWorkspace({db,vendorId,actorId,actorRole}:{db:Firestore;vendorId:string;actorId:string;actorRole:string}) {
  const [accounts,setAccounts]=useState<Row[]>([]);const [owner,setOwner]=useState<Record<string,unknown>>({});
  const [loading,setLoading]=useState(true);const [saving,setSaving]=useState(false);const [error,setError]=useState("");const [notice,setNotice]=useState("");
  const [name,setName]=useState("");const [email,setEmail]=useState("");const [phone,setPhone]=useState("");const [password,setPassword]=useState("");const [role,setRole]=useState("cashier");const [showForm,setShowForm]=useState(false);
  useEffect(()=>{getDoc(doc(db,"vendors",vendorId)).then(snap=>setOwner(snap.data()||{})).catch(e=>setError(e instanceof Error?e.message:"Unable to load restaurant account."));return onSnapshot(query(collection(db,"vendors"),where("ownerId","==",vendorId)),snap=>{setAccounts(snap.docs.map(d=>({...d.data(),id:d.id} as Row)).sort((a,b)=>String(a.name||"").localeCompare(String(b.name||""))));setLoading(false);},e=>{setError(e.message);setLoading(false);});},[db,vendorId]);
  async function createAccount(e:React.FormEvent){e.preventDefault();if(saving)return;const preset=departmentRolePresets.find(x=>x.role===role);if(!preset){setError("Choose a valid department role.");return;}if(!name.trim()||!/^\S+@\S+\.\S+$/.test(email.trim())||password.length<6){setError("Enter a full name, valid email and temporary password of at least 6 characters.");return;}if(!firebaseApp){setError("Firebase is not configured.");return;}setSaving(true);setError("");setNotice("");let secondaryApp:any=null;let secondaryAuth:any=null;let authUserCreated=false;
    try{
      secondaryApp=initializeApp(firebaseApp.options,"department-"+Date.now()+"-"+Math.random().toString(36).slice(2));secondaryAuth=getAuth(secondaryApp);
      const credential=await createUserWithEmailAndPassword(secondaryAuth,email.trim().toLowerCase(),password);const uid=credential.user.uid;authUserCreated=true;const now=new Date();
      const trialEnd=owner.trialEndsAt&&typeof owner.trialEndsAt==="object"&&"seconds" in (owner.trialEndsAt as object)?Timestamp.fromMillis(Number((owner.trialEndsAt as {seconds:number}).seconds)*1000):Timestamp.fromDate(new Date(now.getTime()+3*86400000));
      const accountRef=doc(db,"vendors",uid),staffRef=doc(db,"vendors",vendorId,"staff",uid),batch=writeBatch(db);
      batch.set(accountRef,{ownerId:vendorId,restaurantId:vendorId,branchId:String(owner.branchId||"main"),branchName:String(owner.branchName||"Main Branch"),staffId:uid,email:email.trim().toLowerCase(),name:name.trim(),phoneNo:phone.trim(),role:preset.role,department:preset.department,permissions:[...preset.permissions],createdAt:Timestamp.fromDate(now),isActive:true,trialEndsAt:trialEnd,subscriptionType:String(owner.subscriptionType||"trial"),subscriptionEndsAt:owner.subscriptionEndsAt||null,hasActiveSubscription:owner.hasActiveSubscription===true,location:String(owner.location||""),restaurantName:String(owner.restaurantName||""),restaurantLogoUrl:owner.restaurantLogoUrl||null,createdBy:actorId,photoUrl:null,canChangePhoto:false,showCommissionToStaff:false});
      batch.set(staffRef,{id:uid,authUid:uid,name:name.trim(),role:preset.label,dailyWage:0,phone:phone.trim(),address:"",active:true,joinDate:now.toISOString(),searchKeywords:[name.toLowerCase(),preset.label.toLowerCase(),phone.toLowerCase()].filter(Boolean),photoUrl:null,canChangePhoto:false,commissionRate:0,showCommissionToStaff:false,tipsEarned:0,commissionEarned:0,serviceChargesEarned:0,pointsEarned:0,averageRating:0,reviewCount:0,leakageTotal:0,deductionsTotal:0,branchId:String(owner.branchId||"main"),branchName:String(owner.branchName||"Main Branch")});
      await batch.commit();try{await signOut(secondaryAuth);}catch{/* The secondary auth session is isolated and the app is disposed below. */}setNotice(preset.label+" account created successfully.");setName("");setEmail("");setPhone("");setPassword("");setRole("cashier");setShowForm(false);
    }catch(e){if(authUserCreated&&secondaryAuth?.currentUser){try{await deleteUser(secondaryAuth.currentUser);}catch{/* Best-effort rollback of the newly-created auth account. */}}setError(e instanceof Error?e.message:"Unable to create department account.");}
    finally{if(secondaryApp){try{await deleteApp(secondaryApp);}catch{/* Secondary app cleanup is best-effort. */}}setSaving(false);}
  }
  async function accountAction(row:Row,action:string){const ref=doc(db,"vendors",row.id);const staffId=String(row.staffId||row.id);try{setError("");if(action==="toggle")await updateDoc(ref,{isActive:row.isActive===false,updatedAt:serverTimestamp()});if(action==="reset"){const address=String(row.email||"");if(!address)throw new Error("This account has no email address.");if(!firebaseApp)throw new Error("Firebase is not configured.");await sendPasswordResetEmail(getAuth(firebaseApp),address);setNotice("Password reset email sent.");}if(action==="photo"){const allowed=row.canChangePhoto!==true;await updateDoc(ref,{canChangePhoto:allowed,updatedAt:serverTimestamp()});await setDoc(doc(db,"vendors",vendorId,"staff",staffId),{canChangePhoto:allowed},{merge:true});}if(action==="commission"){const visible=row.showCommissionToStaff!==true;await updateDoc(ref,{showCommissionToStaff:visible,updatedAt:serverTimestamp()});await setDoc(doc(db,"vendors",vendorId,"staff",staffId),{showCommissionToStaff:visible},{merge:true});}}catch(e){setError(e instanceof Error?e.message:"Unable to update department account.");}}
  if(actorRole!=="admin"&&actorRole!=="superAdmin"&&actorRole!=="super_admin")return <section className="admin-module"><h1>Users & roles</h1><p className="error-text">Only restaurant administrators can manage department accounts.</p></section>;
  return <section className="admin-module"><div className="section-head"><div><p className="eyebrow">ACCESS CONTROL</p><h1>Users & roles</h1><p className="muted">Create department logins and control their access to this restaurant</p></div><button className="primary-btn" onClick={()=>setShowForm(v=>!v)}>{showForm?"Close form":"+ Create account"}</button></div>
    {error&&<p className="error-text">{error}</p>}{notice&&<p className="success-text">{notice}</p>}
    {showForm&&<form className="admin-create-form" onSubmit={createAccount}><div className="admin-form-grid"><label>Role / department<select value={role} onChange={e=>setRole(e.target.value)}>{departmentRolePresets.map(p=><option key={p.role} value={p.role}>{p.label} · {p.department}</option>)}</select></label><label>Full name<input required value={name} onChange={e=>setName(e.target.value)}/></label><label>Login email<input required type="email" value={email} onChange={e=>setEmail(e.target.value)}/></label><label>Phone (optional)<input value={phone} onChange={e=>setPhone(e.target.value)}/></label><label>Temporary password<input required type="password" minLength={6} value={password} onChange={e=>setPassword(e.target.value)}/></label></div><p className="admin-note">This creates a Firebase Authentication account, a linked vendor login document and a staff performance profile. The new account inherits this restaurant’s branch and subscription context.</p><button className="primary-btn" disabled={saving}>{saving?"Creating account…":"Create department account"}</button></form>}
    <div className="record-detail"><div className="record-detail-head"><strong>Standard role permissions</strong></div><div className="workflow-lines">{departmentRolePresets.map(p=><div className="workflow-line" key={p.role}><div><strong>{p.label}</strong><small>{p.department}</small><div className="role-permission-chips">{p.permissions.map(x=><span key={x}>{x}</span>)}</div></div></div>)}</div></div>
    <div className="record-detail"><div className="record-detail-head"><strong>Restaurant accounts</strong><span className="count-badge">{accounts.length}</span></div>{loading?<p className="muted">Loading accounts…</p>:!accounts.length?<p className="muted">No department accounts yet. Create a cashier, kitchen, accounts or other login.</p>:<div className="workflow-lines">{accounts.map(row=><div className="workflow-line" key={row.id}><div><strong>{String(row.name||"User")}</strong><small>{String(row.role||"user")} · {String(row.email||"")}</small><small>{row.isActive===false?"Disabled":"Active"} · {String(row.branchName||"Main Branch")}</small></div><div className="record-actions"><button className="secondary-btn" onClick={()=>accountAction(row,"toggle")}>{row.isActive===false?"Enable":"Disable"}</button><button className="secondary-btn" onClick={()=>accountAction(row,"reset")}>Reset password</button><button className="secondary-btn" onClick={()=>accountAction(row,"photo")}>{row.canChangePhoto===true?"Block photo":"Allow photo"}</button><button className="secondary-btn" onClick={()=>accountAction(row,"commission")}>{row.showCommissionToStaff===true?"Hide commission":"Show commission"}</button></div></div>)}</div>}</div>
  </section>;
}

function RecipeWorkspace({db,vendorId,onBack}:{db:Firestore;vendorId:string;onBack:()=>void}) {
  const [products,setProducts]=useState<Row[]>([]);const [ingredients,setIngredients]=useState<Row[]>([]);
  const [productId,setProductId]=useState("");const [items,setItems]=useState<Array<{ingredientId:string;quantityPerUnit:string}>>([]);
  const [saving,setSaving]=useState(false);const [error,setError]=useState("");const [notice,setNotice]=useState("");
  useEffect(()=>onSnapshot(query(collection(db,"vendors",vendorId,"products"),limit(500)),snap=>setProducts(snap.docs.map(d=>({...d.data(),id:d.id} as Row)).filter(x=>x.active!==false)),err=>setError(err.message)),[db,vendorId]);
  useEffect(()=>onSnapshot(query(collection(db,"vendors",vendorId,"ingredients"),limit(500)),snap=>setIngredients(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),err=>setError(err.message)),[db,vendorId]);
  useEffect(()=>{if(!productId){setItems([]);return;}return onSnapshot(doc(db,"vendors",vendorId,"recipes",productId),snap=>{const data=snap.data();setItems(Array.isArray(data?.items)?(data.items as Array<Record<string,unknown>>).map(x=>({ingredientId:String(x.ingredientId||""),quantityPerUnit:String(x.quantityPerUnit??"")})):[]);},err=>setError(err.message));},[db,vendorId,productId]);
  const product=products.find(x=>x.id===productId);
  const producible=items.length&&items.every(x=>x.ingredientId&&Number(x.quantityPerUnit)>0)?Math.min(...items.map(x=>{const ingredient=ingredients.find(i=>i.id===x.ingredientId);return ingredient?Math.floor(Number(ingredient.quantityInStock||0)/Number(x.quantityPerUnit)):0;})):null;
  async function save(){if(!product) {setError("Select a product first.");return;}setSaving(true);setError("");setNotice("");try{if(!items.length)throw new Error("Add at least one ingredient.");const payloadItems=items.map(x=>{const ingredient=ingredients.find(i=>i.id===x.ingredientId),quantity=Number(x.quantityPerUnit);if(!ingredient||!Number.isFinite(quantity)||quantity<=0)throw new Error("Every recipe row needs an ingredient and a positive quantity per product.");return {ingredientId:ingredient.id,ingredientName:String(ingredient.name||""),unit:String(ingredient.unit||""),quantityPerUnit:quantity};});await setDoc(doc(db,"vendors",vendorId,"recipes",product.id),{productId:product.id,productName:String(product.name||""),items:payloadItems,updatedOn:new Date().toISOString()});setNotice("Recipe saved.");}catch(e){setError(e instanceof Error?e.message:"Unable to save recipe.");}finally{setSaving(false);}}
  async function remove(){if(!product)return;if(!window.confirm("Delete the recipe for "+String(product.name||"this product")+"?"))return;setSaving(true);try{await deleteDoc(doc(db,"vendors",vendorId,"recipes",product.id));setItems([]);setNotice("Recipe deleted.");}catch(e){setError(e instanceof Error?e.message:"Unable to delete recipe.");}finally{setSaving(false);}}
  return <section className="admin-module"><div className="section-head"><div><p className="eyebrow">INVENTORY CONTROL</p><h1>Recipe assignment</h1><p className="muted">Define ingredient quantities required to prepare one unit of a product</p></div><button className="secondary-btn" onClick={onBack}>Back to ingredients</button></div>{error&&<p className="error-text">{error}</p>}{notice&&<p className="success-text">{notice}</p>}<div className="admin-create-form"><label>Product<select value={productId} onChange={e=>{setProductId(e.target.value);setNotice("");}}><option value="">Select product</option>{products.map(p=><option key={p.id} value={p.id}>{String(p.name||"Unnamed product")}</option>)}</select></label>{items.map((item,index)=><div className="workflow-editor-grid" key={index}><select value={item.ingredientId} onChange={e=>setItems(current=>current.map((x,i)=>i===index?{...x,ingredientId:e.target.value}:x))}><option value="">Select ingredient</option>{ingredients.map(i=><option key={i.id} value={i.id}>{String(i.name||"Ingredient")} · {String(i.unit||"")}</option>)}</select><input aria-label="Quantity per product" type="number" min="0.000001" step="any" value={item.quantityPerUnit} onChange={e=>setItems(current=>current.map((x,i)=>i===index?{...x,quantityPerUnit:e.target.value}:x))} placeholder="Quantity per product"/><button type="button" className="icon-btn" onClick={()=>setItems(current=>current.filter((_,i)=>i!==index))}>×</button></div>)}<div className="record-actions"><button type="button" className="secondary-btn" onClick={()=>setItems(current=>[...current,{ingredientId:"",quantityPerUnit:""}])}>+ Add ingredient</button><button type="button" className="primary-btn" disabled={saving||!productId} onClick={save}>{saving?"Saving…":"Save recipe"}</button><button type="button" className="secondary-btn danger-btn" disabled={saving||!productId} onClick={remove}>Delete recipe</button></div>{producible!==null&&<p className="admin-note">Estimated producible units from current ingredient stock: <strong>{producible}</strong></p>}</div></section>;
}

function AttendanceWorkspace({db,vendorId,staff}:{db:Firestore;vendorId:string;staff:Row[]}) {
  const today=new Date().toISOString().slice(0,10);
  const [selectedDate,setSelectedDate]=useState(today);
  const [selectedMonth,setSelectedMonth]=useState(today.slice(0,7));
  const [view,setView]=useState<"daily"|"monthly">("daily");
  const [daily,setDaily]=useState<Row[]>([]);
  const [monthly,setMonthly]=useState<Row[]>([]);
  const [search,setSearch]=useState("");
  const [busy,setBusy]=useState("");
  const [error,setError]=useState("");
  useEffect(()=>{
    const start=new Date(selectedDate+"T00:00:00");const end=new Date(start);end.setDate(end.getDate()+1);
    if(!Number.isFinite(start.getTime()))return;
    return onSnapshot(query(collection(db,"vendors",vendorId,"attendance"),where("date",">=",Timestamp.fromDate(start)),where("date","<",Timestamp.fromDate(end))),snap=>setDaily(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),err=>setError(err.message));
  },[db,vendorId,selectedDate]);
  useEffect(()=>{
    const [year,month]=selectedMonth.split("-").map(Number);const start=new Date(year,month-1,1);const end=new Date(year,month,1);
    if(!Number.isFinite(start.getTime()))return;
    return onSnapshot(query(collection(db,"vendors",vendorId,"attendance"),where("date",">=",Timestamp.fromDate(start)),where("date","<",Timestamp.fromDate(end))),snap=>setMonthly(snap.docs.map(d=>({...d.data(),id:d.id} as Row))),err=>setError(err.message));
  },[db,vendorId,selectedMonth]);
  async function mark(staffMember:Row,value:string){
    if(value==="")return;
    const key=String(staffMember.id);setBusy(key);setError("");
    try{
      const start=new Date(selectedDate+"T00:00:00");const end=new Date(start);end.setDate(end.getDate()+1);
      if(!Number.isFinite(start.getTime()))throw new Error("Choose a valid attendance date.");
      const existing=daily.find(x=>String(x.staffId)===key);
      if(existing)await updateDoc(doc(db,"vendors",vendorId,"attendance",existing.id),{isPresent:value==="Present",updatedAt:Timestamp.fromDate(new Date())});
      else{
        const now=new Date();
        const created=await addDoc(collection(db,"vendors",vendorId,"attendance"),{vendorId,staffId:key,staffName:String(staffMember.name||""),dailyWage:Number(staffMember.dailyWage||0),date:Timestamp.fromDate(start),isPresent:value==="Present",checkInTime:null,checkOutTime:null,createdAt:Timestamp.fromDate(now),updatedAt:Timestamp.fromDate(now)});
        await updateDoc(created,{id:created.id});
      }
    }catch(e){setError(e instanceof Error?e.message:"Unable to save attendance.");}
    finally{setBusy("");}
  }
  const activeStaff=staff.filter(x=>x.active!==false&&String(x.name||"").toLowerCase().includes(search.toLowerCase()));
  const monthlySummary=staff.filter(x=>x.active!==false).map(person=>{
    const entries=monthly.filter(x=>String(x.staffId)===person.id);
    let presentDays=0,totalHours=0,totalWage=0;
    for(const entry of entries){
      const present=entry.isPresent===true;if(present)presentDays++;
      const start=dateMillis(entry.checkInTime),end=dateMillis(entry.checkOutTime);
      const hasTimes=start!==null&&end!==null&&end>=start;
      const hours=hasTimes?(end!-start!)/3600000:0;
      totalHours+=hours;
      if(present)totalWage+=hasTimes?(hours/8)*Number(entry.dailyWage||person.dailyWage||0):Number(entry.dailyWage||person.dailyWage||0);
    }
    return {person,presentDays,totalHours,totalWage,records:entries.length};
  }).filter(x=>x.records>0||x.person.name);
  return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">PEOPLE & OPERATIONS</p><h1>Attendance</h1><p className="muted">Daily staff attendance and monthly wage summary</p></div><div className="admin-head-actions"><button className={view==="daily"?"primary-btn":"secondary-btn"} onClick={()=>setView("daily")}>Daily view</button><button className={view==="monthly"?"primary-btn":"secondary-btn"} onClick={()=>setView("monthly")}>Monthly report</button></div></div>
    {error&&<p className="error-text">{error}</p>}
    {view==="daily"?<><div className="record-filter-bar"><label>Attendance date <input type="date" value={selectedDate} onChange={e=>setSelectedDate(e.target.value)} max={today}/></label><div className="search-wrap"><Search size={17}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search staff by name…"/></div><span className="count-badge">{activeStaff.length} staff</span></div><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>#</th><th>Employee</th><th>Role</th><th>Daily wage</th><th>Attendance</th></tr></thead><tbody>{activeStaff.map((person,index)=>{const record=daily.find(x=>String(x.staffId)===person.id);const status=record?(record.isPresent===true?"Present":"Absent"):"";return <tr key={person.id}><td>{index+1}</td><td>{String(person.name||"—")}</td><td>{String(person.role||"—")}</td><td>{Number(person.dailyWage||0).toLocaleString("en-PK")}</td><td><select aria-label={"Attendance for "+String(person.name||"staff")} value={status} disabled={busy===person.id} onChange={e=>mark(person,e.target.value)}><option value="">Not marked</option><option value="Present">Present</option><option value="Absent">Absent</option></select>{busy===person.id&&<small> Saving…</small>}</td></tr>;})}{!activeStaff.length&&<tr><td colSpan={5}>No active staff found.</td></tr>}</tbody></table></div></>:<><div className="record-filter-bar"><label>Month <input type="month" value={selectedMonth} onChange={e=>setSelectedMonth(e.target.value)}/></label><span className="count-badge">{monthly.length} attendance records</span></div><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Staff member</th><th>Present days</th><th>Total hours</th><th>Total wage (Rs)</th></tr></thead><tbody>{monthlySummary.map(x=><tr key={x.person.id}><td>{String(x.person.name||"—")}</td><td>{x.presentDays}</td><td>{x.totalHours.toFixed(1)}</td><td>{x.totalWage.toLocaleString("en-PK",{maximumFractionDigits:0})}</td></tr>)}</tbody></table></div></>}
    <p className="admin-note"><FileText size={17}/> Attendance records use the Flutter-compatible date, staff, wage, status, check-in/out and timestamp fields. Monthly wages follow the source model: full daily wage without both time punches, otherwise prorated over an 8-hour day.</p>
  </section>;
}

function ProductVariantsEditor({value,onChange}:{value:string;onChange:(value:string)=>void}) {
  const [attributeDrafts,setAttributeDrafts]=useState<Record<string,string>>({});
  let variants:Array<Record<string,unknown>>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))variants=parsed;}catch{/* validated on save */}
  function update(index:number,patch:Record<string,unknown>){onChange(JSON.stringify(variants.map((v,i)=>i===index?{...v,...patch}:v),null,2));}
  return <div className="workflow-editor"><div className="workflow-editor-head"><small>{variants.length} variants</small><button type="button" className="secondary-btn" onClick={()=>onChange(JSON.stringify([...variants,{id:crypto.randomUUID(),name:"",priceModifier:0,quantity:0,active:true,attributes:{}}],null,2))}>+ Add variant</button></div><div className="workflow-lines">{variants.map((variant,index)=><div className="variant-editor-row" key={String(variant.id||index)}><div className="workflow-editor-grid"><input aria-label="Variant name" required value={String(variant.name||"")} onChange={e=>update(index,{name:e.target.value})} placeholder="Variant name"/><input aria-label="Variant price modifier" type="number" step="any" value={String(variant.priceModifier??0)} onChange={e=>update(index,{priceModifier:e.target.value===""?0:Number(e.target.value)})} placeholder="Price modifier"/><input aria-label="Variant stock quantity" type="number" min="0" step="1" value={String(variant.quantity??0)} onChange={e=>update(index,{quantity:e.target.value===""?0:Number(e.target.value)})} placeholder="Stock quantity"/><select aria-label="Variant status" value={variant.active===false?"false":"true"} onChange={e=>update(index,{active:e.target.value==="true"})}><option value="true">Active</option><option value="false">Inactive</option></select><button type="button" className="icon-btn" aria-label="Remove variant" onClick={()=>onChange(JSON.stringify(variants.filter((_,i)=>i!==index),null,2))}>×</button></div><textarea rows={2} aria-label="Variant attributes JSON" value={attributeDrafts[String(variant.id||index)]??JSON.stringify(variant.attributes||{},null,2)} onChange={e=>setAttributeDrafts(current=>({...current,[String(variant.id||index)]:e.target.value}))} onBlur={e=>{try{const attrs=JSON.parse(e.target.value);if(attrs&&typeof attrs==="object"&&!Array.isArray(attrs)){update(index,{attributes:attrs});setAttributeDrafts(current=>{const next={...current};delete next[String(variant.id||index)];return next;});}}catch{setAttributeDrafts(current=>{const next={...current};delete next[String(variant.id||index)];return next;});}}} placeholder='{"Size":"Large"}'/></div>)}{!variants.length&&<p className="muted">Add variants when this product has size, flavour or other options. Leave empty for a standard product.</p>}</div></div>;
}

function ProductAttributesEditor({value,onChange}:{value:string;onChange:(value:string)=>void}) {
  let attributes:Array<Record<string,unknown>>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))attributes=parsed;}catch{/* validated on save */}
  function update(index:number,patch:Record<string,unknown>){onChange(JSON.stringify(attributes.map((a,i)=>i===index?{...a,...patch}:a),null,2));}
  return <div className="workflow-editor"><div className="workflow-editor-head"><small>{attributes.length} product attributes</small><button type="button" className="secondary-btn" onClick={()=>onChange(JSON.stringify([...attributes,{id:crypto.randomUUID(),name:"",type:"text",options:[],required:false}],null,2))}>+ Add attribute</button></div><div className="workflow-lines">{attributes.map((attribute,index)=><div className="variant-editor-row" key={String(attribute.id||index)}><div className="workflow-editor-grid"><input aria-label="Attribute name" value={String(attribute.name||"")} onChange={e=>update(index,{name:e.target.value})} placeholder="Attribute name"/><select aria-label="Attribute type" value={String(attribute.type||"text")} onChange={e=>update(index,{type:e.target.value})}><option value="text">Text</option><option value="dropdown">Dropdown</option><option value="number">Number</option><option value="checkbox">Checkbox</option></select><input aria-label="Attribute options" value={Array.isArray(attribute.options)?attribute.options.map(String).join(", "):""} onChange={e=>update(index,{options:e.target.value.split(",").map(x=>x.trim()).filter(Boolean)})} placeholder="Options, comma separated"/><label className="workflow-check"><input type="checkbox" checked={attribute.required===true} onChange={e=>update(index,{required:e.target.checked})}/> Required</label><button type="button" className="icon-btn" aria-label="Remove attribute" onClick={()=>onChange(JSON.stringify(attributes.filter((_,i)=>i!==index),null,2))}>×</button></div></div>)}{!attributes.length&&<p className="muted">Add optional product attributes such as size, flavour or preparation preference.</p>}</div></div>;
}


function StoreOutItemsEditor({products,value,onChange}:{products:Row[];value:string;onChange:(value:string)=>void}) {
  let items:Array<{productId:string;quantity:number}>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed.map(x=>({productId:String(x.productId||""),quantity:Number(x.quantity||1)}));}catch{/* validated on submit */}
  const choices=products.flatMap(product=>[{id:product.id,label:String(product.name||"Product"),available:Number(product.quantity||0),price:Number(product.salePrice||0)},...(Array.isArray(product.variants)?(product.variants as Array<Record<string,unknown>>).filter(v=>v.active!==false).map(v=>({id:product.id+"_"+String(v.id||""),label:String(product.name||"Product")+" - "+String(v.name||"Variant"),available:Number(v.quantity||0),price:Number(product.salePrice||0)+Number(v.priceModifier||0)})):[])]);
  function update(index:number,patch:Partial<{productId:string;quantity:number}>){onChange(JSON.stringify(items.map((x,i)=>i===index?{...x,...patch}:x),null,2));}
  return <div className="workflow-editor"><div className="workflow-lines">{items.map((item,index)=>{const selected=choices.find(x=>x.id===item.productId);return <div className="workflow-line" key={index}><select value={item.productId} onChange={e=>update(index,{productId:e.target.value})}><option value="">Select product / variant</option>{choices.map(x=><option key={x.id} value={x.id}>{x.label} · stock {x.available}</option>)}</select><input aria-label="Store-out quantity" type="number" min="1" step="1" value={item.quantity} onChange={e=>update(index,{quantity:Number(e.target.value)})}/><span>{selected?"Available: "+selected.available:"Choose item"}</span><button type="button" className="icon-btn" onClick={()=>onChange(JSON.stringify(items.filter((_,i)=>i!==index),null,2))}>×</button></div>;})}</div><div className="record-actions"><button type="button" className="secondary-btn" onClick={()=>onChange(JSON.stringify([...items,{productId:"",quantity:1}],null,2))}>+ Add product</button><small>{items.length} outgoing item lines</small></div></div>;
}

function PurchaseItemsEditor({products,value,onChange}:{products:Row[];value:string;onChange:(value:string)=>void}) {
  const [productId,setProductId]=useState(""); const [variantId,setVariantId]=useState(""); const [quantity,setQuantity]=useState("1"); const [unitPrice,setUnitPrice]=useState("");
  let items:Array<Record<string,unknown>>=[]; try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed;}catch{/* validation is performed on save */}
  const product=products.find(x=>x.id===productId); const variants=Array.isArray(product?.variants)?(product.variants as Array<Record<string,unknown>>).filter(x=>x.active!==false):[]; const hasVariants=product?.hasVariants===true; const variant=variants.find(x=>String(x.id)===variantId);
  function add(){if(!product||(hasVariants&&!variant)) return;const q=Number(quantity),price=Number(unitPrice||product.purchasePrice||0);if(!Number.isInteger(q)||q<=0||!Number.isFinite(price)||price<0)return;const name=String(product.name||"Product")+(variant?" - "+String(variant.name||""):"");const next=[...items,{productId:product.id,productName:name,quantity:q,unitPrice:price,total:q*price,variantId:variant?String(variant.id):null,variantName:variant?String(variant.name||""):null}];onChange(JSON.stringify(next,null,2));setQuantity("1");}
  return <div className="workflow-editor"><div className="workflow-editor-grid"><select value={productId} onChange={e=>{const p=products.find(x=>x.id===e.target.value);setProductId(e.target.value);setVariantId("");setUnitPrice(String(p?.purchasePrice||0));}}><option value="">Select product</option>{products.filter(p=>p.active!==false).map(p=><option key={p.id} value={p.id}>{String(p.name||"Unnamed product")} · Stock {Number(p.quantity||0)}</option>)}</select>{hasVariants&&<select value={variantId} onChange={e=>{setVariantId(e.target.value);setUnitPrice(String(product?.purchasePrice||0));}}><option value="">Select variant</option>{variants.map(v=><option key={String(v.id)} value={String(v.id)}>{String(v.name||v.id)} · Stock {Number(v.quantity||0)}</option>)}</select>}<input aria-label="Purchase quantity" type="number" min="1" step="1" value={quantity} onChange={e=>setQuantity(e.target.value)} placeholder="Quantity"/><input aria-label="Purchase unit price" type="number" min="0" step="any" value={unitPrice} onChange={e=>setUnitPrice(e.target.value)} placeholder="Unit price"/><button type="button" className="secondary-btn" disabled={!product||(hasVariants&&!variantId)} onClick={add}>Add item</button></div><div className="workflow-lines">{items.map((item,i)=><div className="workflow-line" key={i}><span>{String(item.productName)} · {Number(item.quantity)} × {display(item.unitPrice)}</span><strong>{display(item.total)}</strong><button type="button" className="icon-btn" aria-label="Remove purchase item" onClick={()=>onChange(JSON.stringify(items.filter((_,j)=>j!==i),null,2))}>×</button></div>)}{!items.length&&<p className="muted">Choose a product, quantity and purchase price, then add it to this purchase.</p>}</div><small>{items.length} line items · Total {items.reduce((sum,item)=>sum+Number(item.total||0),0).toLocaleString("en-PK")}</small></div>;
}

function SaleReturnItemsEditor({sale,value,onChange}:{sale:Row|null;value:string;onChange:(value:string)=>void}) {
  let items:Array<Record<string,unknown>>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed;}catch{/* validated on save */}
  const source=Array.isArray(sale?.items)?sale.items as Array<Record<string,unknown>>:[];
  function toggle(sourceItem:Record<string,unknown>,checked:boolean){const productId=String(sourceItem.productId||sourceItem.id||"");const next=items.filter(x=>String(x.productId)!==productId);if(checked){for(const line of source.filter(x=>String(x.productId||x.id||"")===productId)){const quantity=Number(line.quantity||1),price=Number(line.unitPrice??line.price??line.salePrice??0);next.push({productId,productName:String(line.productName||line.name||"Product"),returnedQuantity:quantity,originalPrice:price,refundAmount:quantity*price});}}onChange(JSON.stringify(next,null,2));}
  return <div className="workflow-editor"><div className="workflow-lines">{!sale&&<p className="muted">Select the original sale above to load its items. All sale items are selected by default; uncheck items not being returned.</p>}{source.map((line,i)=>{const productId=String(line.productId||line.id||"");const selected=items.find(x=>String(x.productId)===productId);const quantity=Number(line.quantity||1),price=Number(line.unitPrice??line.price??line.salePrice??0);return <div className="workflow-line" key={productId+"-"+i}><label className="workflow-check"><input type="checkbox" checked={Boolean(selected)} onChange={e=>toggle(line,e.target.checked)}/><span>{String(line.productName||line.name||"Product")} · sold {quantity}</span></label><span>{quantity} × {display(price)}</span><strong>{selected?display(selected.refundAmount):"—"}</strong></div>;})}</div><small>{items.length} selected lines · Refund total {items.reduce((sum,item)=>sum+Number(item.refundAmount||0),0).toLocaleString("en-PK")}</small></div>;
}

function PurchaseReturnItemsEditor({purchase,value,onChange}:{purchase:Row|null;value:string;onChange:(value:string)=>void}) {
  let items:Array<Record<string,unknown>>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed;}catch{/* validation on save */}
  const source=Array.isArray(purchase?.items)?purchase.items as Array<Record<string,unknown>>:[];
  function toggle(sourceItem:Record<string,unknown>,checked:boolean){const key=String(sourceItem.productId||"");const existing=items.filter(x=>String(x.productId)!==key);if(checked){for(const sourceLine of source.filter(x=>String(x.productId||"")===key)){const qty=Number(sourceLine.quantity||0),price=Number(sourceLine.unitPrice||0);existing.push({productId:key,productName:String(sourceLine.productName||""),returnedQuantity:qty,originalPrice:price,refundAmount:qty*price});}}onChange(JSON.stringify(existing,null,2));}
  return <div className="workflow-editor"><div className="workflow-lines">{!purchase&&<p className="muted">Select the original purchase above to load its products. All purchase items are selected by default, matching the Flutter return flow.</p>}{source.map((sourceItem,i)=>{const key=String(sourceItem.productId||"");const selected=items.find(x=>String(x.productId)===key);const max=Number(sourceItem.quantity||0);return <div className="workflow-line" key={key+"-"+i}><label className="workflow-check"><input type="checkbox" checked={Boolean(selected)} onChange={e=>toggle(sourceItem,e.target.checked)}/><span>{String(sourceItem.productName||"Product")} · purchased {max}</span></label><span>{max} × {display(sourceItem.unitPrice)} </span><strong>{selected?display(selected.refundAmount):"—"}</strong></div>;})}</div><small>{items.length} selected · Refund total {items.reduce((sum,item)=>sum+Number(item.refundAmount||0),0).toLocaleString("en-PK")}</small></div>;
}
