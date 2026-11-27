"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { addDoc, collection, doc, onSnapshot, query, limit, Firestore, Timestamp, updateDoc, deleteDoc, getDocs, getDoc, writeBatch, where, serverTimestamp, orderBy, startAfter, type QueryDocumentSnapshot, type DocumentData } from "firebase/firestore";
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

const editableModules: ModuleKey[] = ["products", "categories", "customers", "suppliers", "discounts", "ingredients", "staff", "expenses", "attendance", "purchases", "purchase_returns", "sale_returns", "store_out"];
const fields: Record<string, string[]> = {
  products: ["name", "category", "unit", "salePrice", "purchasePrice", "quantity", "active", "variantsJson", "attributesJson", "imageUrl"],
  categories: ["name", "imageUrl"],
  customers: ["name", "phone", "email", "address", "city"],
  suppliers: ["name", "phone", "address"],
  discounts: ["name", "description", "type", "value", "imageUrl"],
  ingredients: ["name", "unit", "quantityInStock", "lowStockThreshold"],
  staff: ["name", "role", "dailyWage", "phone", "address", "active", "joinDate", "commissionRate", "showCommissionToStaff"],
  expenses: ["category", "amount", "note"],
  purchases: ["supplierId", "supplierName", "date", "status", "itemsJson"],
  purchase_returns: ["originalPurchaseId", "supplierId", "supplierName", "reason", "itemsJson"],
  sale_returns: ["originalSaleId", "reason", "itemsJson"],
  store_out: ["reason", "handledBy", "date", "productsJson"],
  attendance: ["staffId", "date", "isPresent"],
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
  const [staffOptions, setStaffOptions] = useState<Row[]>([]);
  const [productOptions, setProductOptions] = useState<Row[]>([]);
  const [supplierOptions, setSupplierOptions] = useState<Row[]>([]);
  const [purchaseOptions, setPurchaseOptions] = useState<Row[]>([]);
  const [categoryOptions, setCategoryOptions] = useState<Row[]>([]);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadedPageCount = useRef(0);

  useEffect(() => {
    setLoading(true);
    setError("");
    const ref = collection(db, "vendors", vendorId, config.collection);
    const paged = ["products", "purchases", "purchase_returns"].includes(moduleKey);
    const orderField = moduleKey === "purchase_returns" ? "createdAt" : "createdOn";
    const firstQuery = paged ? query(ref, orderBy(orderField, "desc"), limit(20)) : query(ref, limit(250));
    setLastDoc(null); setHasMore(false); loadedPageCount.current = 0;
    const stop = onSnapshot(firstQuery, snap => {
      const pageRows = snap.docs.map(d => ({ ...d.data(), id: d.id } as Row));
      if (paged && loadedPageCount.current > 0) {
        const pageIds = new Set(pageRows.map(row => row.id));
        setRows(current => [...pageRows, ...current.filter(row => !pageIds.has(row.id))]);
      } else setRows(pageRows);
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
    if (!["purchases", "purchase_returns"].includes(moduleKey)) { setProductOptions([]); setSupplierOptions([]); setPurchaseOptions([]); return; }
    const stops = [
      onSnapshot(query(collection(db, "vendors", vendorId, "products"), limit(500)), snap => setProductOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message)),
      onSnapshot(query(collection(db, "vendors", vendorId, "suppliers"), limit(500)), snap => setSupplierOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message)),
      onSnapshot(query(collection(db, "vendors", vendorId, "purchases"), limit(500)), snap => setPurchaseOptions(snap.docs.map(d => ({ ...d.data(), id: d.id } as Row))), err => setError(err.message)),
    ];
    return () => stops.forEach(stop => stop());
  }, [db, vendorId, moduleKey]);

  async function loadMore() {
    if (!hasMore || !lastDoc || loadingMore) return;
    setLoadingMore(true);
    try {
      const orderField = moduleKey === "purchase_returns" ? "createdAt" : "createdOn";
      const next = await getDocs(query(collection(db, "vendors", vendorId, config.collection), orderBy(orderField, "desc"), startAfter(lastDoc), limit(20)));
      loadedPageCount.current += 1;
      setRows(current => [...current, ...next.docs.map(d => ({ ...d.data(), id: d.id } as Row))]);
      setLastDoc(next.docs.length ? next.docs[next.docs.length - 1] : lastDoc);
      setHasMore(next.docs.length === 20);
    } catch (err) { setError(err instanceof Error ? err.message : "Unable to load more records."); }
    finally { setLoadingMore(false); }
  }

  const filtered = useMemo(
    () => rows.filter(row => JSON.stringify(row).toLowerCase().includes(search.toLowerCase())),
    [rows, search],
  );
  const total = useMemo(() => rows.reduce((sum, row) => {
    const amount = Number(row.total ?? row.amount ?? row.totalAmount ?? 0);
    return sum + (Number.isFinite(amount) ? amount : 0);
  }, 0), [rows]);

  function beginCreate() {
    setImageFile(null);
    setEditingId(null);
    setForm(moduleKey === "attendance" ? { date: new Date().toISOString().slice(0, 10), isPresent: "true" } : moduleKey === "purchases" ? { date: new Date().toISOString().slice(0, 10), status: "Pending", itemsJson: "[]" } : moduleKey === "purchase_returns" ? { itemsJson: "[]" } : {});
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
        quantity: Number(form.quantity || 0), active: form.active !== "false", hasVariants: variants.length > 0, variants, attributes,
        imageUrl: form.imageUrl || "",
      };
    }
    if (moduleKey === "categories") return { name: form.name?.trim() || "", imageUrl: form.imageUrl || "" };
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
    if (moduleKey === "staff") {
      const name = form.name?.trim() || "";
      const role = form.role?.trim() || "";
      if (!name || !role) throw new Error("Staff name and role are required.");
      if ((form.phone || "").replace(/\D/g, "").length < 8) throw new Error("Enter a valid staff phone number.");
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
      let recordId = editingId;
      if (editingId) {
        const patch = moduleKey === "discounts"
          ? { ...payload, updatedAt: Timestamp.fromDate(now) }
          : payload;
        await updateDoc(doc(db, "vendors", vendorId, config.collection, editingId), patch);
      } else {
        let data: Record<string, unknown> = { ...payload };
        if (moduleKey === "products") data = { ...data, id: "", active: payload.active !== false, createdOn: now.toISOString() };
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
      if (!imageFile && editingId && moduleKey === "products" && !String(payload.imageUrl || "") && storage) { const previous=rows.find(row=>row.id===editingId)?.imageUrl; if(typeof previous==="string" && previous){try{await deleteObject(storageRef(storage,previous));}catch{/* Removed product image cleanup is best-effort. */}} }
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
    <RecordsTable moduleKey={moduleKey} rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected}/>
  </section>;

  return <section className="admin-module">
    <div className="section-head"><div><p className="eyebrow">MANAGEMENT</p><h1>{config.title}</h1><p className="muted">{config.description}</p></div><div className="admin-head-actions"><span className="count-badge">{rows.length} records</span>{canEdit && <button className="primary-btn" onClick={beginCreate}>+ Add new</button>}</div></div>
    {formOpen && <form className="admin-create-form" onSubmit={saveRecord}>
      <div className="record-detail-head"><strong>{editingId ? "Edit" : "New"} {config.title.replace(/s$/, "")}</strong><button type="button" className="icon-btn" onClick={() => { setFormOpen(false); setEditingId(null); }}>×</button></div>
      <div className="admin-form-grid">{(fields[moduleKey] || []).map(field => <label key={field}>{field.replace(/([A-Z])/g, " $1")}{["variantsJson", "attributesJson"].includes(field) && <textarea rows={6} value={form[field] || "[]"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}></textarea>}{field === "supplierId" && ["purchases", "purchase_returns"].includes(moduleKey) && <select required value={form.supplierId || ""} onChange={e => { const supplier=supplierOptions.find(x=>x.id===e.target.value); setForm(v=>({...v,supplierId:e.target.value,supplierName:String(supplier?.name||"")})); }}><option value="">Select supplier</option>{supplierOptions.filter(x=>x.active!==false).map(x=><option key={x.id} value={x.id}>{String(x.name||"Unnamed supplier")}</option>)}</select>}{field === "supplierName" && ["purchases", "purchase_returns"].includes(moduleKey) && <input readOnly required value={form.supplierName || ""} placeholder="Choose supplier above"/>}{field === "originalPurchaseId" && moduleKey === "purchase_returns" && <select required value={form.originalPurchaseId || ""} onChange={e=>{const purchase=purchaseOptions.find(x=>x.id===e.target.value);const items=Array.isArray(purchase?.items)?purchase.items as Array<Record<string,unknown>>:[];setForm(v=>({...v,originalPurchaseId:e.target.value,supplierId:String(purchase?.supplierId||""),supplierName:String(purchase?.supplierName||""),itemsJson:JSON.stringify(items.map(item=>({productId:String(item.productId||""),productName:String(item.productName||""),returnedQuantity:Number(item.quantity||0),originalPrice:Number(item.unitPrice||0),refundAmount:Number(item.total||Number(item.quantity||0)*Number(item.unitPrice||0))})),null,2)}));}}><option value="">Select original purchase</option>{purchaseOptions.map(x=><option key={x.id} value={x.id}>{String(x.supplierName||"Supplier")} · {x.id.slice(0,8)} · {display(x.total)}</option>)}</select>}{!["variantsJson", "attributesJson"].includes(field) && !["active", "showCommissionToStaff", "category", "status", "itemsJson", "productsJson", "supplierId", "supplierName", "originalPurchaseId", "imageUrl"].includes(field) && <input required={field === "name" || field === "role" || field === "amount" || (field === "phone" && moduleKey === "staff")} type={["value", "salePrice", "purchasePrice", "quantity", "quantityInStock", "lowStockThreshold", "dailyWage", "commissionRate", "amount"].includes(field) ? "number" : ["joinDate", "date"].includes(field) ? "date" : "text"} step="any" value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}/>}{field === "category" && moduleKey === "products" && <select required value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option value="">Select category</option>{categoryOptions.map(x=><option key={x.id} value={String(x.name||"")}>{String(x.name||"")}</option>)}{!categoryOptions.length&&<option value="General">General</option>}</select>} {field === "productsJson" && moduleKey === "store_out" && <textarea rows={7} value={form[field] || "[{\"productId\":\"PRODUCT_DOC_ID_OR_PRODUCTID_VARIANTID\",\"quantity\":1}]"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}/>} {field === "itemsJson" && moduleKey === "purchases" && <PurchaseItemsEditor products={productOptions} value={form.itemsJson || "[]"} onChange={value=>setForm(v=>({...v,itemsJson:value}))}/>} {field === "itemsJson" && moduleKey === "purchase_returns" && <PurchaseReturnItemsEditor purchase={purchaseOptions.find(x=>x.id===form.originalPurchaseId)||null} value={form.itemsJson||"[]"} onChange={value=>setForm(v=>({...v,itemsJson:value}))}/>} {field === "itemsJson" && moduleKey === "sale_returns" && <textarea rows={7} value={form[field] || "[]"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}/>} {field === "status" && moduleKey === "purchases" && <select value={form[field] || "Pending"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option>Pending</option><option>Received</option><option>Cancelled</option></select>} {field === "staffId" && moduleKey === "attendance" && <select required value={form[field] || ""} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option value="">Select staff member</option>{staffOptions.filter(staff => staff.active !== false).map(staff => <option key={staff.id} value={staff.id}>{String(staff.name || "Unnamed")} · {String(staff.role || "")}</option>)}</select>} {field === "category" && moduleKey === "expenses" && <select value={form[field] || "General"} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}>{["General", "Salaries", "Rent", "Electricity", "Gas", "Maintenance", "Transport", "Marketing", "Purchases", "Other"].map(value => <option key={value}>{value}</option>)}</select>} {["active", "showCommissionToStaff", "isPresent"].includes(field) && <select value={form[field] || (field === "active" ? "true" : "false")} onChange={e => setForm(v => ({ ...v, [field]: e.target.value }))}><option value="true">{field === "isPresent" ? "Present" : "Active"}</option><option value="false">{field === "isPresent" ? "Absent" : "Inactive"}</option></select>}{field === "imageUrl" && ["products", "categories", "discounts"].includes(moduleKey) && <div className="image-field"><input type="file" accept="image/*" onChange={e => setImageFile(e.target.files?.[0] || null)}/>{form.imageUrl && <div className="image-preview"><img src={form.imageUrl} alt="Current image"/><button type="button" className="secondary-btn" onClick={()=>setForm(v=>({...v,imageUrl:""}))}>Remove image</button></div>}{imageFile&&<small>Selected: {imageFile.name}</small>}</div>}</label>)}</div>
      <button className="primary-btn" disabled={saving}>{saving ? "Saving…" : editingId ? "Update record" : "Save record"}</button>
    </form>}
    <RecordsTable moduleKey={moduleKey} rows={filtered} loading={loading} error={error} search={search} setSearch={setSearch} selected={selected} setSelected={setSelected} onLoadMore={loadMore} hasMore={hasMore} loadingMore={loadingMore} canEdit={canEdit && moduleKey !== "expenses" && moduleKey !== "attendance" && moduleKey !== "purchase_returns" && moduleKey !== "sale_returns"} onEdit={beginEdit} onReprint={moduleKey==="sales"?onReprint:undefined} canDelete={moduleKey==="expenses" || moduleKey==="staff" || moduleKey==="products" || moduleKey==="purchases" || moduleKey==="store_out"} onDelete={moduleKey==="expenses" || moduleKey==="staff" || moduleKey==="products" || moduleKey==="purchases" || moduleKey==="store_out"?async row=>{const label=moduleKey==="staff"?"employee":moduleKey==="products"?"product":moduleKey==="purchases"?"purchase":moduleKey==="store_out"?"store movement":"expense";if(!window.confirm(`Delete this ${label} record${moduleKey==="staff" && row.name?` for ${String(row.name)}`:""}?`))return;try{if(moduleKey==="purchases"){const items=Array.isArray(row.items)?row.items as Array<Record<string,unknown>>:[];const ids=Array.from(new Set(items.map(item=>String(item.productId))));const snaps=await Promise.all(ids.map(id=>getDoc(doc(db,"vendors",vendorId,"products",id))));const batch=writeBatch(db);for(let i=0;i<ids.length;i++){if(!snaps[i].exists())continue;const data=snaps[i].data() || {};const selectedItems=items.filter(item=>String(item.productId)===ids[i]);const base=selectedItems.filter(item=>!item.variantId).reduce((s,item)=>s+Number(item.quantity||0),0);const vd=new Map<string,number>();for(const item of selectedItems)if(item.variantId){const id=String(item.variantId);vd.set(id,(vd.get(id)||0)+Number(item.quantity||0));}const patch:Record<string,unknown>={};if(base)patch.quantity=Number(data.quantity||0)-base;if(vd.size)patch.variants=(Array.isArray(data.variants)?data.variants:[]).map((v:Record<string,unknown>)=>vd.has(String(v.id))?{...v,quantity:Number(v.quantity||0)-(vd.get(String(v.id))||0)}:v);if(Object.keys(patch).length)batch.update(snaps[i].ref,patch);}batch.delete(doc(db,"vendors",vendorId,"purchases",row.id));await batch.commit();}else if(moduleKey==="products"){await deleteDoc(doc(db,"vendors",vendorId,"products",row.id));if(storage && typeof row.imageUrl==="string" && row.imageUrl){try{await deleteObject(storageRef(storage,row.imageUrl));}catch{/* Storage cleanup is best-effort after catalog deletion. */}}}else if(moduleKey==="store_out") await updateDoc(doc(db,"vendors",vendorId,"store_outs",row.id),{active:false});else { await deleteDoc(doc(db,"vendors",vendorId,config.collection,row.id)); }setSelected(null)}catch(err){setError(err instanceof Error?err.message:`Unable to delete ${label}.`)}}:undefined}/>
    <p className="admin-note"><FileText size={17}/> This module is a migration slice. Unsupported workflow side effects, permissions and validations are not simulated here.</p>
  </section>;
}

function RecordsTable({ moduleKey, rows, loading, error, search, setSearch, selected, setSelected, canEdit = false, onEdit, onReprint, canDelete = false, onDelete, onLoadMore, hasMore = false, loadingMore = false }: {
  moduleKey?: ModuleKey; rows: Row[]; loading: boolean; error: string; search: string; setSearch: (s: string) => void;
  selected: Row | null; setSelected: (r: Row | null) => void; canEdit?: boolean; onEdit?: (r: Row) => void; onReprint?:(r:Row)=>void; canDelete?: boolean; onDelete?: (r:Row)=>void; onLoadMore?:()=>void; hasMore?:boolean; loadingMore?:boolean;
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
    {selected && <div className="record-detail"><div className="record-detail-head"><strong>{moduleKey==="purchase_returns"?"Purchase return details":moduleKey==="purchases"?"Purchase details":moduleKey==="products"?"Product details":"Record details"}</strong><div className="record-actions">{canEdit && onEdit && <button className="secondary-btn" onClick={() => onEdit(selected)}>Edit record</button>}{canDelete && onDelete && <button className="secondary-btn danger-btn" onClick={() => onDelete(selected)}>Delete record</button>}{onReprint&&<button className="secondary-btn" onClick={()=>onReprint(selected)}>Reprint receipt</button>}<button className="icon-btn" onClick={() => setSelected(null)}>×</button></div></div>{["purchases","purchase_returns"].includes(moduleKey||"") ? <><p><b>{moduleKey==="purchases"?"Supplier":"Supplier"}:</b> {String(selected.supplierName||"—")}</p><p><b>{moduleKey==="purchases"?"Purchase":"Original purchase"}:</b> {String(moduleKey==="purchases"?selected.id:selected.originalPurchaseId||"—")}</p><p><b>Total:</b> {display(moduleKey==="purchases"?selected.total:selected.totalRefund)}</p><p><b>{moduleKey==="purchases"?"Status":"Reason"}:</b> {String(moduleKey==="purchases"?selected.status:selected.reason||"—")}</p><div className="admin-table-wrap"><table className="admin-table"><thead><tr>{(moduleKey==="purchases"?["Product","Qty","Unit price","Line total"]:["Product","Original price","Qty returned","Refund"]).map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{(Array.isArray(selected.items)?selected.items as Array<Record<string,unknown>>:[]).map((item,i)=><tr key={i}><td>{String(item.productName||"—")}</td><td>{moduleKey==="purchases"?Number(item.quantity||0):display(item.originalPrice)}</td><td>{moduleKey==="purchases"?display(item.unitPrice):Number(item.returnedQuantity||0)}</td><td>{display(moduleKey==="purchases"?item.total:item.refundAmount)}</td></tr>)}</tbody></table></div></>:moduleKey==="products"&&selected.imageUrl?<img className="detail-product-image" src={String(selected.imageUrl)} alt={String(selected.name||"Product")}/>:null}<pre>{JSON.stringify(selected, null, 2)}</pre></div>}
    {onLoadMore && hasMore && <div className="load-more-row"><button className="secondary-btn" onClick={onLoadMore} disabled={loadingMore}>{loadingMore?"Loading…":"Load more records"}</button></div>}
  </>;
}


function PurchaseItemsEditor({products,value,onChange}:{products:Row[];value:string;onChange:(value:string)=>void}) {
  const [productId,setProductId]=useState(""); const [variantId,setVariantId]=useState(""); const [quantity,setQuantity]=useState("1"); const [unitPrice,setUnitPrice]=useState("");
  let items:Array<Record<string,unknown>>=[]; try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed;}catch{/* validation is performed on save */}
  const product=products.find(x=>x.id===productId); const variants=Array.isArray(product?.variants)?product.variants as Array<Record<string,unknown>>:[]; const variant=variants.find(x=>String(x.id)===variantId);
  function add(){if(!product) return;const q=Number(quantity),price=Number(unitPrice||product.purchasePrice||0);if(!Number.isInteger(q)||q<=0||!Number.isFinite(price)||price<0)return;const name=String(product.name||"Product")+(variant?" - "+String(variant.name||""):"");const next=[...items,{productId:product.id,productName:name,quantity:q,unitPrice:price,total:q*price,variantId:variant?String(variant.id):null,variantName:variant?String(variant.name||""):null}];onChange(JSON.stringify(next,null,2));setQuantity("1");}
  return <div className="workflow-editor"><div className="workflow-editor-grid"><select value={productId} onChange={e=>{const p=products.find(x=>x.id===e.target.value);setProductId(e.target.value);setVariantId("");setUnitPrice(String(p?.purchasePrice||0));}}><option value="">Select product</option>{products.map(p=><option key={p.id} value={p.id}>{String(p.name||"Unnamed product")} · Stock {Number(p.quantity||0)}</option>)}</select>{variants.length>0&&<select value={variantId} onChange={e=>{setVariantId(e.target.value);setUnitPrice(String(product?.purchasePrice||0));}}><option value="">Select variant</option>{variants.map(v=><option key={String(v.id)} value={String(v.id)}>{String(v.name||v.id)} · Stock {Number(v.quantity||0)}</option>)}</select>}<input aria-label="Purchase quantity" type="number" min="1" step="1" value={quantity} onChange={e=>setQuantity(e.target.value)} placeholder="Quantity"/><input aria-label="Purchase unit price" type="number" min="0" step="any" value={unitPrice} onChange={e=>setUnitPrice(e.target.value)} placeholder="Unit price"/><button type="button" className="secondary-btn" disabled={!product||(variants.length>0&&!variantId)} onClick={add}>Add item</button></div><div className="workflow-lines">{items.map((item,i)=><div className="workflow-line" key={i}><span>{String(item.productName)} · {Number(item.quantity)} × {display(item.unitPrice)}</span><strong>{display(item.total)}</strong><button type="button" className="icon-btn" aria-label="Remove purchase item" onClick={()=>onChange(JSON.stringify(items.filter((_,j)=>j!==i),null,2))}>×</button></div>)}{!items.length&&<p className="muted">Choose a product, quantity and purchase price, then add it to this purchase.</p>}</div><small>{items.length} line items · Total {items.reduce((sum,item)=>sum+Number(item.total||0),0).toLocaleString("en-PK")}</small></div>;
}

function PurchaseReturnItemsEditor({purchase,value,onChange}:{purchase:Row|null;value:string;onChange:(value:string)=>void}) {
  let items:Array<Record<string,unknown>>=[];try{const parsed=JSON.parse(value||"[]");if(Array.isArray(parsed))items=parsed;}catch{/* validation on save */}
  const source=Array.isArray(purchase?.items)?purchase.items as Array<Record<string,unknown>>:[];
  function toggle(sourceItem:Record<string,unknown>,checked:boolean){const key=String(sourceItem.productId||"");const existing=items.filter(x=>String(x.productId)!==key);if(checked){const qty=Number(sourceItem.quantity||0),price=Number(sourceItem.unitPrice||0);existing.push({productId:key,productName:String(sourceItem.productName||""),returnedQuantity:qty,originalPrice:price,refundAmount:qty*price});}onChange(JSON.stringify(existing,null,2));}
  function changeQty(item:Record<string,unknown>,qty:number){const next=items.map(x=>String(x.productId)===String(item.productId)?{...x,returnedQuantity:qty,refundAmount:qty*Number(x.originalPrice||0)}:x);onChange(JSON.stringify(next,null,2));}
  return <div className="workflow-editor"><div className="workflow-lines">{!purchase&&<p className="muted">Select the original purchase above to load its products. All purchase items are selected by default, matching the Flutter return flow.</p>}{source.map((sourceItem,i)=>{const key=String(sourceItem.productId||"");const selected=items.find(x=>String(x.productId)===key);const max=Number(sourceItem.quantity||0);return <div className="workflow-line" key={key+"-"+i}><label className="workflow-check"><input type="checkbox" checked={Boolean(selected)} onChange={e=>toggle(sourceItem,e.target.checked)}/><span>{String(sourceItem.productName||"Product")} · purchased {max}</span></label>{selected&&<input aria-label="Returned quantity" type="number" min="1" max={max} step="1" value={String(selected.returnedQuantity||1)} onChange={e=>changeQty(selected,Math.max(1,Math.min(max,Number(e.target.value)||1)))}/>}<strong>{selected?display(selected.refundAmount):"—"}</strong></div>;})}</div><small>{items.length} selected · Refund total {items.reduce((sum,item)=>sum+Number(item.refundAmount||0),0).toLocaleString("en-PK")}</small></div>;
}
