var pe = Object.defineProperty;
var ue = (n, e, t) => e in n ? pe(n, e, { enumerable: !0, configurable: !0, writable: !0, value: t }) : n[e] = t;
var w = (n, e, t) => (ue(n, typeof e != "symbol" ? e + "" : e, t), t);
/**
 * @license
 * Copyright 2019 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const U = globalThis, D = U.ShadowRoot && (U.ShadyCSS === void 0 || U.ShadyCSS.nativeShadow) && "adoptedStyleSheets" in Document.prototype && "replace" in CSSStyleSheet.prototype, K = Symbol(), Z = /* @__PURE__ */ new WeakMap();
let ne = class {
  constructor(e, t, i) {
    if (this._$cssResult$ = !0, i !== K)
      throw Error("CSSResult is not constructable. Use `unsafeCSS` or `css` instead.");
    this.cssText = e, this.t = t;
  }
  get styleSheet() {
    let e = this.o;
    const t = this.t;
    if (D && e === void 0) {
      const i = t !== void 0 && t.length === 1;
      i && (e = Z.get(t)), e === void 0 && ((this.o = e = new CSSStyleSheet()).replaceSync(this.cssText), i && Z.set(t, e));
    }
    return e;
  }
  toString() {
    return this.cssText;
  }
};
const ve = (n) => new ne(typeof n == "string" ? n : n + "", void 0, K), q = (n, ...e) => {
  const t = n.length === 1 ? n[0] : e.reduce((i, s, r) => i + ((o) => {
    if (o._$cssResult$ === !0)
      return o.cssText;
    if (typeof o == "number")
      return o;
    throw Error("Value passed to 'css' function must be a 'css' function result: " + o + ". Use 'unsafeCSS' to pass non-literal values, but take care to ensure page security.");
  })(s) + n[r + 1], n[0]);
  return new ne(t, n, K);
}, ge = (n, e) => {
  if (D)
    n.adoptedStyleSheets = e.map((t) => t instanceof CSSStyleSheet ? t : t.styleSheet);
  else
    for (const t of e) {
      const i = document.createElement("style"), s = U.litNonce;
      s !== void 0 && i.setAttribute("nonce", s), i.textContent = t.cssText, n.appendChild(i);
    }
}, F = D ? (n) => n : (n) => n instanceof CSSStyleSheet ? ((e) => {
  let t = "";
  for (const i of e.cssRules)
    t += i.cssText;
  return ve(t);
})(n) : n;
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const { is: _e, defineProperty: me, getOwnPropertyDescriptor: $e, getOwnPropertyNames: fe, getOwnPropertySymbols: be, getPrototypeOf: ye } = Object, m = globalThis, J = m.trustedTypes, we = J ? J.emptyScript : "", O = m.reactiveElementPolyfillSupport, S = (n, e) => n, I = { toAttribute(n, e) {
  switch (e) {
    case Boolean:
      n = n ? we : null;
      break;
    case Object:
    case Array:
      n = n == null ? n : JSON.stringify(n);
  }
  return n;
}, fromAttribute(n, e) {
  let t = n;
  switch (e) {
    case Boolean:
      t = n !== null;
      break;
    case Number:
      t = n === null ? null : Number(n);
      break;
    case Object:
    case Array:
      try {
        t = JSON.parse(n);
      } catch {
        t = null;
      }
  }
  return t;
} }, oe = (n, e) => !_e(n, e), G = { attribute: !0, type: String, converter: I, reflect: !1, hasChanged: oe };
Symbol.metadata ?? (Symbol.metadata = Symbol("metadata")), m.litPropertyMetadata ?? (m.litPropertyMetadata = /* @__PURE__ */ new WeakMap());
class x extends HTMLElement {
  static addInitializer(e) {
    this._$Ei(), (this.l ?? (this.l = [])).push(e);
  }
  static get observedAttributes() {
    return this.finalize(), this._$Eh && [...this._$Eh.keys()];
  }
  static createProperty(e, t = G) {
    if (t.state && (t.attribute = !1), this._$Ei(), this.elementProperties.set(e, t), !t.noAccessor) {
      const i = Symbol(), s = this.getPropertyDescriptor(e, i, t);
      s !== void 0 && me(this.prototype, e, s);
    }
  }
  static getPropertyDescriptor(e, t, i) {
    const { get: s, set: r } = $e(this.prototype, e) ?? { get() {
      return this[t];
    }, set(o) {
      this[t] = o;
    } };
    return { get() {
      return s == null ? void 0 : s.call(this);
    }, set(o) {
      const h = s == null ? void 0 : s.call(this);
      r.call(this, o), this.requestUpdate(e, h, i);
    }, configurable: !0, enumerable: !0 };
  }
  static getPropertyOptions(e) {
    return this.elementProperties.get(e) ?? G;
  }
  static _$Ei() {
    if (this.hasOwnProperty(S("elementProperties")))
      return;
    const e = ye(this);
    e.finalize(), e.l !== void 0 && (this.l = [...e.l]), this.elementProperties = new Map(e.elementProperties);
  }
  static finalize() {
    if (this.hasOwnProperty(S("finalized")))
      return;
    if (this.finalized = !0, this._$Ei(), this.hasOwnProperty(S("properties"))) {
      const t = this.properties, i = [...fe(t), ...be(t)];
      for (const s of i)
        this.createProperty(s, t[s]);
    }
    const e = this[Symbol.metadata];
    if (e !== null) {
      const t = litPropertyMetadata.get(e);
      if (t !== void 0)
        for (const [i, s] of t)
          this.elementProperties.set(i, s);
    }
    this._$Eh = /* @__PURE__ */ new Map();
    for (const [t, i] of this.elementProperties) {
      const s = this._$Eu(t, i);
      s !== void 0 && this._$Eh.set(s, t);
    }
    this.elementStyles = this.finalizeStyles(this.styles);
  }
  static finalizeStyles(e) {
    const t = [];
    if (Array.isArray(e)) {
      const i = new Set(e.flat(1 / 0).reverse());
      for (const s of i)
        t.unshift(F(s));
    } else
      e !== void 0 && t.push(F(e));
    return t;
  }
  static _$Eu(e, t) {
    const i = t.attribute;
    return i === !1 ? void 0 : typeof i == "string" ? i : typeof e == "string" ? e.toLowerCase() : void 0;
  }
  constructor() {
    super(), this._$Ep = void 0, this.isUpdatePending = !1, this.hasUpdated = !1, this._$Em = null, this._$Ev();
  }
  _$Ev() {
    var e;
    this._$ES = new Promise((t) => this.enableUpdating = t), this._$AL = /* @__PURE__ */ new Map(), this._$E_(), this.requestUpdate(), (e = this.constructor.l) == null || e.forEach((t) => t(this));
  }
  addController(e) {
    var t;
    (this._$EO ?? (this._$EO = /* @__PURE__ */ new Set())).add(e), this.renderRoot !== void 0 && this.isConnected && ((t = e.hostConnected) == null || t.call(e));
  }
  removeController(e) {
    var t;
    (t = this._$EO) == null || t.delete(e);
  }
  _$E_() {
    const e = /* @__PURE__ */ new Map(), t = this.constructor.elementProperties;
    for (const i of t.keys())
      this.hasOwnProperty(i) && (e.set(i, this[i]), delete this[i]);
    e.size > 0 && (this._$Ep = e);
  }
  createRenderRoot() {
    const e = this.shadowRoot ?? this.attachShadow(this.constructor.shadowRootOptions);
    return ge(e, this.constructor.elementStyles), e;
  }
  connectedCallback() {
    var e;
    this.renderRoot ?? (this.renderRoot = this.createRenderRoot()), this.enableUpdating(!0), (e = this._$EO) == null || e.forEach((t) => {
      var i;
      return (i = t.hostConnected) == null ? void 0 : i.call(t);
    });
  }
  enableUpdating(e) {
  }
  disconnectedCallback() {
    var e;
    (e = this._$EO) == null || e.forEach((t) => {
      var i;
      return (i = t.hostDisconnected) == null ? void 0 : i.call(t);
    });
  }
  attributeChangedCallback(e, t, i) {
    this._$AK(e, i);
  }
  _$EC(e, t) {
    var r;
    const i = this.constructor.elementProperties.get(e), s = this.constructor._$Eu(e, i);
    if (s !== void 0 && i.reflect === !0) {
      const o = (((r = i.converter) == null ? void 0 : r.toAttribute) !== void 0 ? i.converter : I).toAttribute(t, i.type);
      this._$Em = e, o == null ? this.removeAttribute(s) : this.setAttribute(s, o), this._$Em = null;
    }
  }
  _$AK(e, t) {
    var r;
    const i = this.constructor, s = i._$Eh.get(e);
    if (s !== void 0 && this._$Em !== s) {
      const o = i.getPropertyOptions(s), h = typeof o.converter == "function" ? { fromAttribute: o.converter } : ((r = o.converter) == null ? void 0 : r.fromAttribute) !== void 0 ? o.converter : I;
      this._$Em = s, this[s] = h.fromAttribute(t, o.type), this._$Em = null;
    }
  }
  requestUpdate(e, t, i) {
    if (e !== void 0) {
      if (i ?? (i = this.constructor.getPropertyOptions(e)), !(i.hasChanged ?? oe)(this[e], t))
        return;
      this.P(e, t, i);
    }
    this.isUpdatePending === !1 && (this._$ES = this._$ET());
  }
  P(e, t, i) {
    this._$AL.has(e) || this._$AL.set(e, t), i.reflect === !0 && this._$Em !== e && (this._$Ej ?? (this._$Ej = /* @__PURE__ */ new Set())).add(e);
  }
  async _$ET() {
    this.isUpdatePending = !0;
    try {
      await this._$ES;
    } catch (t) {
      Promise.reject(t);
    }
    const e = this.scheduleUpdate();
    return e != null && await e, !this.isUpdatePending;
  }
  scheduleUpdate() {
    return this.performUpdate();
  }
  performUpdate() {
    var i;
    if (!this.isUpdatePending)
      return;
    if (!this.hasUpdated) {
      if (this.renderRoot ?? (this.renderRoot = this.createRenderRoot()), this._$Ep) {
        for (const [r, o] of this._$Ep)
          this[r] = o;
        this._$Ep = void 0;
      }
      const s = this.constructor.elementProperties;
      if (s.size > 0)
        for (const [r, o] of s)
          o.wrapped !== !0 || this._$AL.has(r) || this[r] === void 0 || this.P(r, this[r], o);
    }
    let e = !1;
    const t = this._$AL;
    try {
      e = this.shouldUpdate(t), e ? (this.willUpdate(t), (i = this._$EO) == null || i.forEach((s) => {
        var r;
        return (r = s.hostUpdate) == null ? void 0 : r.call(s);
      }), this.update(t)) : this._$EU();
    } catch (s) {
      throw e = !1, this._$EU(), s;
    }
    e && this._$AE(t);
  }
  willUpdate(e) {
  }
  _$AE(e) {
    var t;
    (t = this._$EO) == null || t.forEach((i) => {
      var s;
      return (s = i.hostUpdated) == null ? void 0 : s.call(i);
    }), this.hasUpdated || (this.hasUpdated = !0, this.firstUpdated(e)), this.updated(e);
  }
  _$EU() {
    this._$AL = /* @__PURE__ */ new Map(), this.isUpdatePending = !1;
  }
  get updateComplete() {
    return this.getUpdateComplete();
  }
  getUpdateComplete() {
    return this._$ES;
  }
  shouldUpdate(e) {
    return !0;
  }
  update(e) {
    this._$Ej && (this._$Ej = this._$Ej.forEach((t) => this._$EC(t, this[t]))), this._$EU();
  }
  updated(e) {
  }
  firstUpdated(e) {
  }
}
x.elementStyles = [], x.shadowRootOptions = { mode: "open" }, x[S("elementProperties")] = /* @__PURE__ */ new Map(), x[S("finalized")] = /* @__PURE__ */ new Map(), O == null || O({ ReactiveElement: x }), (m.reactiveElementVersions ?? (m.reactiveElementVersions = [])).push("2.0.4");
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
const C = globalThis, T = C.trustedTypes, Q = T ? T.createPolicy("lit-html", { createHTML: (n) => n }) : void 0, re = "$lit$", _ = `lit$${Math.random().toFixed(9).slice(2)}$`, ae = "?" + _, xe = `<${ae}>`, y = document, M = () => y.createComment(""), z = (n) => n === null || typeof n != "object" && typeof n != "function", le = Array.isArray, Ae = (n) => le(n) || typeof (n == null ? void 0 : n[Symbol.iterator]) == "function", R = `[ 	
\f\r]`, E = /<(?:(!--|\/[^a-zA-Z])|(\/?[a-zA-Z][^>\s]*)|(\/?$))/g, X = /-->/g, Y = />/g, $ = RegExp(`>|${R}(?:([^\\s"'>=/]+)(${R}*=${R}*(?:[^ 	
\f\r"'\`<>=]|("|')|))|$)`, "g"), ee = /'/g, te = /"/g, he = /^(?:script|style|textarea|title)$/i, ke = (n) => (e, ...t) => ({ _$litType$: n, strings: e, values: t }), u = ke(1), A = Symbol.for("lit-noChange"), c = Symbol.for("lit-nothing"), ie = /* @__PURE__ */ new WeakMap(), f = y.createTreeWalker(y, 129);
function de(n, e) {
  if (!Array.isArray(n) || !n.hasOwnProperty("raw"))
    throw Error("invalid template strings array");
  return Q !== void 0 ? Q.createHTML(e) : e;
}
const Ee = (n, e) => {
  const t = n.length - 1, i = [];
  let s, r = e === 2 ? "<svg>" : "", o = E;
  for (let h = 0; h < t; h++) {
    const a = n[h];
    let d, p, l = -1, v = 0;
    for (; v < a.length && (o.lastIndex = v, p = o.exec(a), p !== null); )
      v = o.lastIndex, o === E ? p[1] === "!--" ? o = X : p[1] !== void 0 ? o = Y : p[2] !== void 0 ? (he.test(p[2]) && (s = RegExp("</" + p[2], "g")), o = $) : p[3] !== void 0 && (o = $) : o === $ ? p[0] === ">" ? (o = s ?? E, l = -1) : p[1] === void 0 ? l = -2 : (l = o.lastIndex - p[2].length, d = p[1], o = p[3] === void 0 ? $ : p[3] === '"' ? te : ee) : o === te || o === ee ? o = $ : o === X || o === Y ? o = E : (o = $, s = void 0);
    const g = o === $ && n[h + 1].startsWith("/>") ? " " : "";
    r += o === E ? a + xe : l >= 0 ? (i.push(d), a.slice(0, l) + re + a.slice(l) + _ + g) : a + _ + (l === -2 ? h : g);
  }
  return [de(n, r + (n[t] || "<?>") + (e === 2 ? "</svg>" : "")), i];
};
class V {
  constructor({ strings: e, _$litType$: t }, i) {
    let s;
    this.parts = [];
    let r = 0, o = 0;
    const h = e.length - 1, a = this.parts, [d, p] = Ee(e, t);
    if (this.el = V.createElement(d, i), f.currentNode = this.el.content, t === 2) {
      const l = this.el.content.firstChild;
      l.replaceWith(...l.childNodes);
    }
    for (; (s = f.nextNode()) !== null && a.length < h; ) {
      if (s.nodeType === 1) {
        if (s.hasAttributes())
          for (const l of s.getAttributeNames())
            if (l.endsWith(re)) {
              const v = p[o++], g = s.getAttribute(l).split(_), P = /([.?@])?(.*)/.exec(v);
              a.push({ type: 1, index: r, name: P[2], strings: g, ctor: P[1] === "." ? Ce : P[1] === "?" ? Me : P[1] === "@" ? ze : N }), s.removeAttribute(l);
            } else
              l.startsWith(_) && (a.push({ type: 6, index: r }), s.removeAttribute(l));
        if (he.test(s.tagName)) {
          const l = s.textContent.split(_), v = l.length - 1;
          if (v > 0) {
            s.textContent = T ? T.emptyScript : "";
            for (let g = 0; g < v; g++)
              s.append(l[g], M()), f.nextNode(), a.push({ type: 2, index: ++r });
            s.append(l[v], M());
          }
        }
      } else if (s.nodeType === 8)
        if (s.data === ae)
          a.push({ type: 2, index: r });
        else {
          let l = -1;
          for (; (l = s.data.indexOf(_, l + 1)) !== -1; )
            a.push({ type: 7, index: r }), l += _.length - 1;
        }
      r++;
    }
  }
  static createElement(e, t) {
    const i = y.createElement("template");
    return i.innerHTML = e, i;
  }
}
function k(n, e, t = n, i) {
  var o, h;
  if (e === A)
    return e;
  let s = i !== void 0 ? (o = t._$Co) == null ? void 0 : o[i] : t._$Cl;
  const r = z(e) ? void 0 : e._$litDirective$;
  return (s == null ? void 0 : s.constructor) !== r && ((h = s == null ? void 0 : s._$AO) == null || h.call(s, !1), r === void 0 ? s = void 0 : (s = new r(n), s._$AT(n, t, i)), i !== void 0 ? (t._$Co ?? (t._$Co = []))[i] = s : t._$Cl = s), s !== void 0 && (e = k(n, s._$AS(n, e.values), s, i)), e;
}
class Se {
  constructor(e, t) {
    this._$AV = [], this._$AN = void 0, this._$AD = e, this._$AM = t;
  }
  get parentNode() {
    return this._$AM.parentNode;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  u(e) {
    const { el: { content: t }, parts: i } = this._$AD, s = ((e == null ? void 0 : e.creationScope) ?? y).importNode(t, !0);
    f.currentNode = s;
    let r = f.nextNode(), o = 0, h = 0, a = i[0];
    for (; a !== void 0; ) {
      if (o === a.index) {
        let d;
        a.type === 2 ? d = new H(r, r.nextSibling, this, e) : a.type === 1 ? d = new a.ctor(r, a.name, a.strings, this, e) : a.type === 6 && (d = new Ve(r, this, e)), this._$AV.push(d), a = i[++h];
      }
      o !== (a == null ? void 0 : a.index) && (r = f.nextNode(), o++);
    }
    return f.currentNode = y, s;
  }
  p(e) {
    let t = 0;
    for (const i of this._$AV)
      i !== void 0 && (i.strings !== void 0 ? (i._$AI(e, i, t), t += i.strings.length - 2) : i._$AI(e[t])), t++;
  }
}
class H {
  get _$AU() {
    var e;
    return ((e = this._$AM) == null ? void 0 : e._$AU) ?? this._$Cv;
  }
  constructor(e, t, i, s) {
    this.type = 2, this._$AH = c, this._$AN = void 0, this._$AA = e, this._$AB = t, this._$AM = i, this.options = s, this._$Cv = (s == null ? void 0 : s.isConnected) ?? !0;
  }
  get parentNode() {
    let e = this._$AA.parentNode;
    const t = this._$AM;
    return t !== void 0 && (e == null ? void 0 : e.nodeType) === 11 && (e = t.parentNode), e;
  }
  get startNode() {
    return this._$AA;
  }
  get endNode() {
    return this._$AB;
  }
  _$AI(e, t = this) {
    e = k(this, e, t), z(e) ? e === c || e == null || e === "" ? (this._$AH !== c && this._$AR(), this._$AH = c) : e !== this._$AH && e !== A && this._(e) : e._$litType$ !== void 0 ? this.$(e) : e.nodeType !== void 0 ? this.T(e) : Ae(e) ? this.k(e) : this._(e);
  }
  S(e) {
    return this._$AA.parentNode.insertBefore(e, this._$AB);
  }
  T(e) {
    this._$AH !== e && (this._$AR(), this._$AH = this.S(e));
  }
  _(e) {
    this._$AH !== c && z(this._$AH) ? this._$AA.nextSibling.data = e : this.T(y.createTextNode(e)), this._$AH = e;
  }
  $(e) {
    var r;
    const { values: t, _$litType$: i } = e, s = typeof i == "number" ? this._$AC(e) : (i.el === void 0 && (i.el = V.createElement(de(i.h, i.h[0]), this.options)), i);
    if (((r = this._$AH) == null ? void 0 : r._$AD) === s)
      this._$AH.p(t);
    else {
      const o = new Se(s, this), h = o.u(this.options);
      o.p(t), this.T(h), this._$AH = o;
    }
  }
  _$AC(e) {
    let t = ie.get(e.strings);
    return t === void 0 && ie.set(e.strings, t = new V(e)), t;
  }
  k(e) {
    le(this._$AH) || (this._$AH = [], this._$AR());
    const t = this._$AH;
    let i, s = 0;
    for (const r of e)
      s === t.length ? t.push(i = new H(this.S(M()), this.S(M()), this, this.options)) : i = t[s], i._$AI(r), s++;
    s < t.length && (this._$AR(i && i._$AB.nextSibling, s), t.length = s);
  }
  _$AR(e = this._$AA.nextSibling, t) {
    var i;
    for ((i = this._$AP) == null ? void 0 : i.call(this, !1, !0, t); e && e !== this._$AB; ) {
      const s = e.nextSibling;
      e.remove(), e = s;
    }
  }
  setConnected(e) {
    var t;
    this._$AM === void 0 && (this._$Cv = e, (t = this._$AP) == null || t.call(this, e));
  }
}
class N {
  get tagName() {
    return this.element.tagName;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  constructor(e, t, i, s, r) {
    this.type = 1, this._$AH = c, this._$AN = void 0, this.element = e, this.name = t, this._$AM = s, this.options = r, i.length > 2 || i[0] !== "" || i[1] !== "" ? (this._$AH = Array(i.length - 1).fill(new String()), this.strings = i) : this._$AH = c;
  }
  _$AI(e, t = this, i, s) {
    const r = this.strings;
    let o = !1;
    if (r === void 0)
      e = k(this, e, t, 0), o = !z(e) || e !== this._$AH && e !== A, o && (this._$AH = e);
    else {
      const h = e;
      let a, d;
      for (e = r[0], a = 0; a < r.length - 1; a++)
        d = k(this, h[i + a], t, a), d === A && (d = this._$AH[a]), o || (o = !z(d) || d !== this._$AH[a]), d === c ? e = c : e !== c && (e += (d ?? "") + r[a + 1]), this._$AH[a] = d;
    }
    o && !s && this.j(e);
  }
  j(e) {
    e === c ? this.element.removeAttribute(this.name) : this.element.setAttribute(this.name, e ?? "");
  }
}
class Ce extends N {
  constructor() {
    super(...arguments), this.type = 3;
  }
  j(e) {
    this.element[this.name] = e === c ? void 0 : e;
  }
}
class Me extends N {
  constructor() {
    super(...arguments), this.type = 4;
  }
  j(e) {
    this.element.toggleAttribute(this.name, !!e && e !== c);
  }
}
class ze extends N {
  constructor(e, t, i, s, r) {
    super(e, t, i, s, r), this.type = 5;
  }
  _$AI(e, t = this) {
    if ((e = k(this, e, t, 0) ?? c) === A)
      return;
    const i = this._$AH, s = e === c && i !== c || e.capture !== i.capture || e.once !== i.once || e.passive !== i.passive, r = e !== c && (i === c || s);
    s && this.element.removeEventListener(this.name, this, i), r && this.element.addEventListener(this.name, this, e), this._$AH = e;
  }
  handleEvent(e) {
    var t;
    typeof this._$AH == "function" ? this._$AH.call(((t = this.options) == null ? void 0 : t.host) ?? this.element, e) : this._$AH.handleEvent(e);
  }
}
class Ve {
  constructor(e, t, i) {
    this.element = e, this.type = 6, this._$AN = void 0, this._$AM = t, this.options = i;
  }
  get _$AU() {
    return this._$AM._$AU;
  }
  _$AI(e) {
    k(this, e);
  }
}
const W = C.litHtmlPolyfillSupport;
W == null || W(V, H), (C.litHtmlVersions ?? (C.litHtmlVersions = [])).push("3.1.3");
const He = (n, e, t) => {
  const i = (t == null ? void 0 : t.renderBefore) ?? e;
  let s = i._$litPart$;
  if (s === void 0) {
    const r = (t == null ? void 0 : t.renderBefore) ?? null;
    i._$litPart$ = s = new H(e.insertBefore(M(), r), r, void 0, t ?? {});
  }
  return s._$AI(n), s;
};
/**
 * @license
 * Copyright 2017 Google LLC
 * SPDX-License-Identifier: BSD-3-Clause
 */
class b extends x {
  constructor() {
    super(...arguments), this.renderOptions = { host: this }, this._$Do = void 0;
  }
  createRenderRoot() {
    var t;
    const e = super.createRenderRoot();
    return (t = this.renderOptions).renderBefore ?? (t.renderBefore = e.firstChild), e;
  }
  update(e) {
    const t = this.render();
    this.hasUpdated || (this.renderOptions.isConnected = this.isConnected), super.update(e), this._$Do = He(t, this.renderRoot, this.renderOptions);
  }
  connectedCallback() {
    var e;
    super.connectedCallback(), (e = this._$Do) == null || e.setConnected(!0);
  }
  disconnectedCallback() {
    var e;
    super.disconnectedCallback(), (e = this._$Do) == null || e.setConnected(!1);
  }
  render() {
    return A;
  }
}
var se;
b._$litElement$ = !0, b.finalized = !0, (se = globalThis.litElementHydrateSupport) == null || se.call(globalThis, { LitElement: b });
const B = globalThis.litElementPolyfillSupport;
B == null || B({ LitElement: b });
(globalThis.litElementVersions ?? (globalThis.litElementVersions = [])).push("4.0.5");
class Pe extends b {
  connectedCallback() {
    super.connectedCallback(), window.addEventListener("click", this.handleWindowClick.bind(this)), window.addEventListener("keydown", this.handleWindowKeydown.bind(this)), this.addEventListener("il-header-nav-section-expanded", this.handleNavigationSectionToggleClick.bind(this));
  }
  handleNavigationSectionToggleClick(e) {
    e.stopPropagation();
    const t = e.target, i = e.detail, s = this.getSections();
    if (i) {
      s.forEach((r) => r.expanded = r === t || r.contains(t));
      return;
    }
    if (t.closest("il-header-nav-section, il-header-nav-section-with-link")) {
      const r = t.parentElement.closest("il-header-nav-section, il-header-nav-section-with-link");
      s.forEach((o) => o.expanded = o === r || o.contains(r));
      return;
    }
    this.closeAllSections();
  }
  handleWindowClick(e) {
    this.contains(e.target) || this.closeAllSections();
  }
  handleWindowKeydown(e) {
    e.key === "Escape" && this.closeAllSections();
  }
  closeAllSections() {
    this.getSections().forEach((e) => e.expanded = !1);
  }
  getSections() {
    return this.querySelectorAll("il-header-nav-section, il-header-nav-section-with-link");
  }
  render() {
    return u`
      <nav aria-label="Main">
        <slot></slot>
      </nav>
    `;
  }
}
customElements.define("il-header-nav", Pe);
class L extends b {
  handleToggleClick(e) {
    this.dispatchEvent(new CustomEvent("il-header-nav-section-expanded", { detail: !this.expanded, bubbles: !0, composed: !0 }));
  }
  renderArrow() {
    return u`<svg class="arrow" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40.4 23.82" aria-hidden="true">
      <path id="chevron" d="m39.34,1.06c-1.41-1.41-3.7-1.41-5.12,0l-14.02,14.02L6.18,1.06C4.76-.35,2.47-.35,1.06,1.06s-1.41,3.7,0,5.12l16.58,16.58c1.41,1.41,3.7,1.41,5.12,0L39.34,6.18c1.41-1.41,1.41-3.7,0-5.12Z"/>
    </svg>`;
  }
  renderItems() {
    return u`<div id="items" class="items">
      <slot></slot>
    </div>`;
  }
  render() {
    return u`
      <div class="section ${this.expanded ? "expanded" : "collapsed"}">
        <button class="toggle" @click=${this.handleToggleClick.bind(this)} aria-expanded=${this.expanded ? "true" : "false"} aria-controls="items">
          <div class="header">
            <div class="label"><slot name="label"></slot></div>
            <div class="icon">
              ${this.renderArrow()}
            </div>
          </div>
          <div class="overlay"></div>
        </button>
        ${this.renderItems()}
      </div>
    `;
  }
}
w(L, "properties", {
  expanded: { type: Boolean, reflect: !0, default: !1 }
}), w(L, "styles", q`
    :host {
      display: block;
    }
    .section {
      position: relative;
    }
    .toggle {
      all: initial;
      position: relative;
      width: 100%;
      display: block;
      background: var(--il-header-nav-section__header__background);
      border-color: var(--il-header-nav-section__header__border-color);
      border-style: solid;
      border-width: var(--il-header-nav-section__header__border-width);
      box-sizing: border-box;
      cursor: pointer;
    }
    .toggle:focus {
      background: #C7EDF8;
      border-color: var(--il-blue);
    }
    .header {
      position: relative;
      display: grid;
      grid-template-columns: auto 44px;
      grid-template-areas: "label icon";
      grid-gap: 4px;
    }
    .label {
      box-sizing: border-box;
      color: var(--il-blue);
      display: block;
      font: var(--il-header-nav-section__label__font);
      padding-left: var(--il-header-nav-section__label__padding-left);
      padding-right: var(--il-header-nav-section__label__padding-right);
      padding-top: var(--il-header-nav-section__label__padding-top);
      padding-bottom: var(--il-header-nav-section__label__padding-bottom);
      position: relative;
      grid-area: label;
    }
    .toggle:hover .label {
      color: var(--il-altgeld);
    }
    .toggle:focus .label {
      color: var(--il-blue);
    }
    .icon {
      align-self: center;
      display: flex;
      align-items: center;
      justify-content: center;
      grid-area: icon;
    }
    .arrow {
      display: block;
      fill: var(--il-blue);
      height: 14px;
      transform: var(--il-header-nav-section__arrow__transform);
      width: 14px;
    }
    .toggle:hover .arrow {
      fill: var(--il-altgeld);
    }
    .toggle:focus .arrow {
      fill: var(--il-blue);
    }
    .overlay {
      display: block;
      position: absolute;
      outline: 2px dotted var(--il-altgeld);
      left: var(--il-header-nav-section__overlay__left);
      right: var(--il-header-nav-section__overlay__right);
      top: var(--il-header-nav-section__overlay__top);
      bottom: var(--il-header-nav-section__overlay__bottom);
      visibility: hidden;
    }
    .toggle:hover .overlay {
      visibility: visible;
    }
    .items {
      display: none;
      left: var(--il-header-nav-section__items__left);
      position: var(--il-header-nav-section__items__position);
      top: var(--il-header-nav-section__items__top);
    }
    .section.expanded .items {
      display: block;
    }
  `);
customElements.define("il-header-nav-section", L);
class ce extends L {
  render() {
    return u`
      <div class="section with-link ${this.expanded ? "expanded" : "collapsed"}">
        <div class="header">
          <div class="link" id="link">
            <slot name="link"></slot>
          </div>
          <button class="toggle" @click=${this.handleToggleClick.bind(this)} aria-expanded=${this.expanded ? "true" : "false"} aria-controls="items" aria-labelledby="link">
            ${this.renderArrow()}
          </button>
        </div>
        ${this.renderItems()}
      </div>`;
  }
}
w(ce, "styles", q`
    :host {
      display: block;
    }
    .section {
      position: relative;
    }
    .header {
      all: initial;
      background: var(--il-header-nav-section-with-link__header__background);
      border-color: var(--il-header-nav-section-with-link__header__border-color);
      border-style: solid;
      border-width: var(--il-header-nav-section-with-link__header__border-width);
      box-sizing: border-box;
      display: grid;
      grid-gap: var(--il-header-nav-section-with-link__header__grid-gap);
      grid-template-areas: var(--il-header-nav-section-with-link__header__grid-template-areas);
      grid-template-columns: var(--il-header-nav-section-with-link__header__grid-template-columns);
      padding: var(--il-header-nav-section-with-link__header__padding);
      position: relative;
    }
    .link {
      grid-area: link;
    }
    .toggle {
      all: initial;
      background: transparent;
      border-color: transparent;
      border-style: solid;
      border-width: 0 0 2px;
      box-sizing: border-box;
      cursor: pointer;
      grid-area: toggle;
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
      width: var(--il-header-nav-section-with-link__toggle__width);
    }
    .toggle:focus {
      background: #C7EDF8;
      border-color: var(--il-blue);
      color: var(--il-blue);
    }
    .toggle:hover {
      color: var(--il-altgeld);
      outline: 2px dotted var(--il-altgeld);
    }
    .arrow {
      all: initial;
      display: block;
      fill: var(--il-blue);
      height: 14px;
      pointer-events: none;
      transform: var(--il-header-nav-section-with-link__arrow__transform);
      width: 14px;
    }
    .toggle:hover .arrow {
      fill: var(--il-altgeld);
    }
    .items {
      display: none;
      left: var(--il-header-nav-section-with-link__items__left);
      position: var(--il-header-nav-section-with-link__items__position);
      top: var(--il-header-nav-section-with-link__items__top);
    }
    .section.expanded .items {
      display: block;
    }
  `);
customElements.define("il-header-nav-section-with-link", ce);
class j extends b {
  constructor() {
    super(), this.handleWindowClick = this.handleWindowClick.bind(this), this.handleWindowKeydown = this.handleWindowKeydown.bind(this), this.handleWindowResize = this.handleWindowResize.bind(this);
  }
  connectedCallback() {
    super.connectedCallback(), this.setAttribute("data-initialized", "1"), window.addEventListener("click", this.handleWindowClick), window.addEventListener("keydown", this.handleWindowKeydown), window.addEventListener("resize", this.handleWindowResize), this.setCompactModeBasedOnWidth();
  }
  disconnectedCallback() {
    super.disconnectedCallback(), window.removeEventListener("click", this.handleWindowClick), window.removeEventListener("keydown", this.handleWindowKeydown), window.removeEventListener("resize", this.handleWindowResize);
  }
  handleWindowClick(e) {
    this.compact && this.expanded && !this.contains(e.target) && (this.expanded = !1);
  }
  handleWindowKeydown(e) {
    this.compact && e.key === "Escape" && this.expanded && (this.expanded = !1);
  }
  handleWindowResize() {
    this.setCompactModeBasedOnWidth();
  }
  handleToggleClick() {
    this.expanded = !this.expanded;
  }
  hasLinks() {
    return this.querySelector('*[slot="links"]');
  }
  hasNavigation() {
    return this.querySelector('*[slot="navigation"]');
  }
  hasSearch() {
    return this.querySelector('*[slot="search"]');
  }
  hasMenuContents() {
    return this.hasLinks() || this.hasSearch() || this.hasNavigation();
  }
  setCompactModeBasedOnWidth() {
    this.offsetWidth < 990 ? this.compact || (this.compact = !0) : this.compact && (this.compact = !1);
  }
  renderBlockI() {
    return u`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 34.67">
        <path class="outline"
              d="M24 9.33V0H0v9.33h5.33v16H0v9.33h24v-9.33h-5.33v-16H24zm-5.33 17.34h4v6.67H1.33v-6.67h4c.74 0 1.33-.6 1.33-1.33v-16C6.67 8.6 6.07 8 5.33 8h-4V1.33h21.33V8h-4c-.74 0-1.33.6-1.33 1.33v16c0 .74.6 1.34 1.34 1.34z"
        />
        <path class="fill"
              d="M18.67 8h4V1.33H1.33V8h4c.74 0 1.33.6 1.33 1.33v16c0 .74-.6 1.33-1.33 1.33h-4v6.67h21.33v-6.67h-4c-.74 0-1.33-.6-1.33-1.33v-16c0-.73.6-1.33 1.34-1.33z"
        />
      </svg>`;
  }
  renderWordmark() {
    return u`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 378.6 10.1">
      <title>University of Illinois Urbana-Champaign</title>
      <path d="M376.4.2v5.9L371.5.2h-1.9V10h2.3V4l4.8 6h1.9V.2zM361.1 2.3c.5-.3 1-.4 1.7-.4 1 0 1.8.4 2.5 1.1l1.5-1.3c-.5-.6-1.1-1-1.8-1.3-.7-.3-1.5-.4-2.3-.4-1 0-2 .2-2.8.7-.8.4-1.5 1-1.9 1.8-.5.8-.7 1.6-.7 2.6s.2 1.8.7 2.6c.5.8 1.1 1.4 1.9 1.8.8.4 1.7.6 2.7.6.7 0 1.4-.1 2.1-.3.7-.2 1.3-.5 1.8-.9v-4h-2.1v2.9c-.5.3-1.1.4-1.8.4-.6 0-1.2-.1-1.7-.4-.5-.3-.8-.6-1.1-1.1-.3-.5-.4-1-.4-1.6 0-.6.1-1.2.4-1.6.5-.5.8-.9 1.3-1.2zM352.4.2h2.3V10h-2.3zM343.8.2l-4.4 9.8h2.3l.9-2.1h4.5l.9 2.1h2.4L346 .2h-2.2zm-.4 5.9 1.6-3.8 1.6 3.8h-3.2zM336.7.6c-.6-.3-1.4-.4-2.3-.4h-4.2V10h2.3V7.3h2c.9 0 1.6-.1 2.3-.4.6-.3 1.1-.7 1.5-1.2.3-.5.5-1.2.5-1.9s-.2-1.4-.5-1.9c-.4-.6-.9-1-1.6-1.3zm-.8 4.4c-.4.3-.9.4-1.6.4h-1.8V2h1.8c.7 0 1.2.1 1.6.4.4.3.5.7.5 1.3 0 .6-.1 1-.5 1.3zM325.1.2l-3.6 6.1-3.7-6.1H316V10h2.1V4.2l2.8 4.7h1.1l2.9-4.8V10h2.1V.2zM307.4.2 303 10h2.3l.9-2.1h4.6l.9 2.1h2.4L309.7.2h-2.3zm-.4 5.9 1.6-3.8 1.6 3.8H307zM298.8 4h-4.4V.2h-2.3V10h2.3V6h4.4v4h2.3V.2h-2.3zM284.1 2.3c.5-.3 1-.4 1.6-.4 1 0 1.8.4 2.5 1.1l1.5-1.3c-.5-.6-1-1-1.7-1.3-.7-.3-1.4-.4-2.3-.4-1 0-1.9.2-2.7.7-.8.4-1.4 1-1.9 1.8s-.7 1.6-.7 2.6.2 1.8.7 2.6c.5.8 1.1 1.4 1.9 1.8.8.4 1.7.6 2.7.6.8 0 1.6-.1 2.3-.4.7-.3 1.3-.7 1.7-1.3L288.2 7c-.7.8-1.5 1.2-2.5 1.2-.6 0-1.1-.1-1.6-.4-.5-.3-.9-.6-1.1-1.1-.3-.5-.4-1-.4-1.6 0-.6.1-1.1.4-1.6.3-.5.6-.9 1.1-1.2zM274.1 5.2h4V7h-4zM266.3.2 262 10h2.3l.9-2.1h4.6l.9 2.1h2.4L268.7.2h-2.4zm-.4 5.9 1.6-3.8 1.6 3.8h-3.2zM257.8 6.1 252.9.2H251V10h2.3V4l4.9 6h1.8V.2h-2.2zM242.5.2l-4.4 9.8h2.3l.9-2.1h4.5l.9 2.1h2.4L244.7.2h-2.2zm-.5 5.9 1.6-3.8 1.6 3.8H242zM235 4.9c.4-.2.7-.5 1-.9.2-.4.4-.8.4-1.3 0-.8-.3-1.4-1-1.9-.6-.5-1.5-.7-2.7-.7h-4.8V10h5.1c1.3 0 2.2-.2 2.9-.7.7-.5 1-1.1 1-2 0-.6-.2-1.1-.5-1.5-.4-.5-.8-.8-1.4-.9zm-4.9-3h2.3c.6 0 1 .1 1.3.3.3.2.4.5.4.9s-.1.7-.4.9-.7.3-1.3.3h-2.3V1.9zM234 8c-.3.2-.7.3-1.3.3h-2.6V5.8h2.6c1.2 0 1.8.4 1.8 1.2 0 .5-.1.8-.5 1zM224.6 5.6c.4-.5.5-1.2.5-1.9s-.2-1.4-.5-1.9-.8-.9-1.5-1.2c-.6-.3-1.4-.4-2.3-.4h-4.2V10h2.3V7.2h2.1l1.9 2.7h2.4l-2.2-3.1c.6-.3 1.1-.7 1.5-1.2zm-2.3-.6c-.4.3-.9.4-1.6.4h-1.8V2h1.8c.7 0 1.2.1 1.6.4.4.3.5.7.5 1.3 0 .6-.2 1-.5 1.3zM211.2 5.6c0 .9-.2 1.6-.6 2-.4.4-.9.6-1.6.6-1.5 0-2.2-.9-2.2-2.6V.2h-2.3v5.5c0 1.4.4 2.5 1.2 3.3.8.8 1.9 1.2 3.3 1.2s2.5-.4 3.3-1.2c.8-.8 1.2-1.9 1.2-3.3V.2h-2.2v5.4zM195.6 4.7c-.5-.2-1.1-.4-1.8-.5-.7-.2-1.3-.3-1.6-.5-.3-.2-.5-.4-.5-.8s.1-.6.4-.8c.3-.2.8-.3 1.4-.3.9 0 1.8.3 2.7.8l.7-1.7c-.4-.3-1-.5-1.6-.6-.6-.1-1.2-.2-1.8-.2-.9 0-1.7.1-2.3.4-.6.3-1.1.6-1.4 1.1-.3.5-.5 1-.5 1.5 0 .7.2 1.2.5 1.6.3.4.8.7 1.2.9.5.2 1.1.4 1.8.5.5.1.9.2 1.1.3.3.1.5.2.7.4.2.1.3.3.3.6s-.2.6-.5.8c-.3.2-.8.3-1.4.3-.6 0-1.2-.1-1.7-.3s-1.1-.4-1.5-.7l-.6 1.5c.4.3 1 .6 1.7.8.7.2 1.5.3 2.3.3.9 0 1.7-.1 2.3-.4s1.1-.6 1.4-1.1c.3-.5.5-1 .5-1.5 0-.7-.2-1.2-.5-1.6-.4-.3-.8-.6-1.3-.8zM184.4.2h2.3V10h-2.3zM179.2.7c-.8-.4-1.7-.7-2.7-.7-1 0-1.9.2-2.8.7-.8.4-1.5 1-1.9 1.8-.5.8-.7 1.6-.7 2.6s.2 1.8.7 2.6c.5.8 1.1 1.4 1.9 1.8.8.4 1.7.7 2.8.7 1 0 1.9-.2 2.7-.7.8-.4 1.5-1 1.9-1.8.5-.8.7-1.6.7-2.6s-.2-1.8-.7-2.6c-.4-.8-1.1-1.4-1.9-1.8zm-.1 6c-.3.5-.6.8-1.1 1.1-.5.3-1 .4-1.6.4-.6 0-1.1-.1-1.6-.4-.5-.3-.8-.6-1.1-1.1-.3-.5-.4-1-.4-1.6 0-.6.1-1.1.4-1.6.3-.5.6-.8 1.1-1.1.5-.3 1-.4 1.6-.4.6 0 1.1.1 1.6.4.5.3.8.6 1.1 1.1.3.5.4 1 .4 1.6 0 .6-.1 1.1-.4 1.6zM166.2 6.1 161.4.2h-1.9V10h2.2V4l4.9 6h1.9V.2h-2.3zM154 .2h2.3V10H154zM146.9.2h-2.3V10h7.2V8.1h-4.9zM137.5.2h-2.2V10h7.2V8.1h-5zM129.8.2h2.3V10h-2.3zM115 10h2.3V6.4h4.6V4.6h-4.6V2h5.2V.2H115zM109.8.7c-.8-.5-1.7-.7-2.7-.7-1 0-1.9.2-2.8.7-.8.4-1.5 1-1.9 1.8-.5.8-.7 1.6-.7 2.6s.2 1.8.7 2.6c.5.8 1.1 1.4 1.9 1.8.8.4 1.7.7 2.8.7 1 0 1.9-.2 2.7-.7.8-.4 1.5-1 1.9-1.8.5-.8.7-1.6.7-2.6s-.2-1.8-.7-2.6c-.4-.8-1.1-1.4-1.9-1.8zm-.1 6c-.3.5-.6.8-1.1 1.1-.5.3-1 .4-1.6.4s-1.1-.1-1.6-.4c-.5-.3-.8-.6-1.1-1.1-.3-.5-.4-1-.4-1.6 0-.6.1-1.1.4-1.6.3-.5.6-.8 1.1-1.1.5-.3 1-.4 1.6-.4s1.1.1 1.6.4c.5.3.8.6 1.1 1.1.3.5.4 1 .4 1.6 0 .6-.1 1.1-.4 1.6zM90.7 4.5 88.1.2h-2.4l3.8 6.3V10h2.3V6.5L95.6.2h-2.2zM76.6 2h3.1v8H82V2h3.1V.2h-8.5zM72.2.2h2.3V10h-2.3zM68 4.7c-.5-.2-1.1-.4-1.8-.5-.7-.2-1.3-.3-1.6-.5-.4-.2-.6-.4-.6-.8s.1-.6.4-.8c.3-.2.8-.3 1.4-.3.9 0 1.8.3 2.7.8l.7-1.7c-.4-.3-1-.5-1.6-.6-.5-.2-1.1-.3-1.7-.3-.9 0-1.7.1-2.3.4-.6.3-1.1.6-1.4 1.1-.3.5-.5 1-.5 1.5 0 .7.2 1.2.5 1.6.4.4.8.7 1.3.9.5.2 1.1.3 1.8.5.5.1.9.2 1.1.3.3.1.5.2.7.4.2.1.3.3.3.6s-.2.6-.5.8c-.3.2-.8.3-1.4.3-.6 0-1.2-.1-1.7-.3-.6-.2-1.1-.4-1.5-.7L61.6 9c.4.3 1 .6 1.7.8.7.2 1.5.3 2.3.3.9 0 1.7-.1 2.3-.4.6-.3 1.1-.6 1.4-1.1.3-.5.5-1 .5-1.5 0-.7-.2-1.2-.5-1.6-.4-.3-.8-.6-1.3-.8zM59.1 5.6c.4-.5.5-1.2.5-1.9s-.2-1.4-.5-1.9-.8-.9-1.5-1.2C57 .3 56.2.2 55.3.2h-4.2V10h2.3V7.2h2.1l1.9 2.7h2.4l-2.2-3.1c.7-.3 1.2-.7 1.5-1.2zM56.8 5c-.4.3-.9.4-1.6.4h-1.8V2h1.8c.7 0 1.2.1 1.6.4.4.3.5.7.5 1.3 0 .6-.1 1-.5 1.3zM43.1 5.9h4.5V4.1h-4.5V2h5.1V.2h-7.4V10h7.6V8.1h-5.3zM33.8 7.2l-2.9-7h-2.5l4.2 9.8h2.3L39.1.2h-2.2zM24.2.2h2.3V10h-2.3zM18.8 6.1 13.9.2H12V10h2.3V4l4.9 6H21V.2h-2.2zM6.6 5.6c0 .9-.2 1.6-.6 2-.3.4-.8.6-1.5.6-1.5 0-2.2-.9-2.2-2.6V.2H0v5.5C0 7.1.4 8.2 1.2 9c.8.8 1.9 1.2 3.3 1.2S7 9.8 7.8 9C8.6 8.2 9 7.1 9 5.7V.2H6.6v5.4z"/>
    </svg>`;
  }
  renderBranding() {
    return u`
      <a href="https://illinois.edu">
        <div class="block-i" aria-hidden="true">${this.renderBlockI()}</div>
        <div class="wordmark">${this.renderWordmark()}</div>
      </a>`;
  }
  renderMenuIcon() {
    return this.expanded ? this.renderMenuCloseIcon() : this.renderMenuOpenIcon();
  }
  renderMenuCloseIcon() {
    return u`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 51.26 51.26">
      <path d="m37.84 32.94-7.63-7.63 7.63-7.63a3.24 3.24 0 0 0-4.58-4.58l-7.63 7.63L18 13.1a3.24 3.24 0 0 0-4.58 4.58L21 25.31l-7.62 7.63A3.24 3.24 0 1 0 18 37.52l7.63-7.63 7.63 7.63a3.24 3.24 0 0 0 4.58-4.58Z"/>
    </svg>`;
  }
  renderMenuOpenIcon() {
    return u`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 51.26 51.26">
      <path d="M11.6 16.52h28.06a3.24 3.24 0 1 0 0-6.48H11.6a3.24 3.24 0 0 0 0 6.48ZM39.66 22.07H11.6a3.24 3.24 0 0 0 0 6.48h28.06a3.24 3.24 0 1 0 0-6.48ZM39.66 34.1H11.6a3.24 3.24 0 0 0 0 6.48h28.06a3.24 3.24 0 1 0 0-6.48Z"/>
    </svg>`;
  }
  renderMenuButton() {
    return u`<span class="button">
      <span class="icon" role="presentation" aria-hidden="true">${this.renderMenuIcon()}</span>
      <span class="label">Menu</span>
    </span>`;
  }
  renderMenuToggle() {
    return u`
      <div class="menu-toggle">
        <button aria-controls="menu" aria-expanded=${this.expanded ? "true" : "false"} @click=${this.handleToggleClick.bind(this)}>
          ${this.renderMenuButton()}
        </button>
      </div>`;
  }
  renderMenu() {
    return u`
      <div id="menu" class="menu">
        <div class="links">
          <slot name="links"></slot>
        </div>
        <div class="search">
          <slot name="search"></slot>
        </div>
        <div class="nav">
          <slot name="navigation"></slot>
        </div>
      </div>`;
  }
  renderCompact() {
    return u`
      <header class="compact header ${this.expanded ? "expanded" : "collapsed"}">
        <div class="main">
          <div class="illinois">
            ${this.renderBranding()}
          </div>
          <div class="identity">
            <div>
              <slot name="primary-unit"></slot>
            </div>
            <div>
              <slot name="site-name"></slot>
            </div>
          </div>
          ${this.hasMenuContents() ? this.renderMenuToggle() : ""}
        </div>
        ${this.hasMenuContents() ? this.renderMenu() : ""}
      </header>`;
  }
  renderFull() {
    return u`
      <header class="full header">
        <div class="main">
          <div class="illinois">
            ${this.renderBranding()}
          </div>
          <div class="links">
            <slot name="links"></slot>
          </div>
          <div class="identity">
            <div>
              <slot name="primary-unit"></slot>
            </div>
            <div>
              <slot name="site-name"></slot>
            </div>
          </div>
          <div class="search">
            <slot name="search"></slot>
          </div>
          <div class="nav">
            <slot name="navigation"></slot>
          </div>
        </div>
      </header>`;
  }
  render() {
    return this.compact ? this.renderCompact() : this.renderFull();
  }
}
w(j, "properties", {
  compact: { type: Boolean, reflect: !0 },
  expanded: { type: Boolean },
  _hasMenu: { state: !0 },
  _menuVisible: { state: !0 }
}), w(j, "styles", q`
    :host {
      display: block;
    }
    .main {
      display: grid;
    }
    .full.header .main {
      grid-template-columns: 30px 435px auto auto 355px 30px;
      grid-template-rows: 63px auto auto auto;
      grid-template-areas: ". illinois links links links ." ". identity identity identity search ." "nav nav nav nav nav nav";
    }
    .compact.header .main {
      grid-template-columns: 30px auto 60px 30px;
      grid-template-rows: 63px auto;
      grid-template-areas: ". illinois illinois ." ". identity toggle .";
    }
    .illinois {
      grid-area: illinois;
    }
    .illinois a {
      all: initial;
      position: relative;
      top: -8px;
      display: block;
      width: 44px;
      height: 51px;
      overflow: hidden;
      cursor: pointer;
    }
    .illinois .block-i {
      display: block;
      width: 44px;
      height: 51px;
      position: absolute;
      top: 0;
      left: 0;
      background: var(--il-blue);
    }
    .illinois .block-i svg {
      display: block;
      position: absolute;
      width: 22px;
      height: 31px;
      left: 10px;
      top: 10px;
    }
    .illinois .block-i .outline {
      fill: white;
    }
    .illinois .block-i .fill {
      fill: var(--il-orange);
    }
    .illinois .wordmark {
      display: block;
      width: 379px;
      height: 11px;
      position: absolute;
      top: 21px;
      left: 55px;
      z-index: 10;
    }
    .illinois .wordmark svg {
      display: block;
      position: relative;
      width: 100%;
      height: 100%;
      fill: var(--il-blue);
    }
    .illinois a:hover .wordmark svg {
      fill: var(--il-altgeld);
    }
    .links {
      grid-area: links;
    }
    .identity {
      grid-area: identity;
      padding-bottom: 20px;
    }
    .search {
      grid-area: search;
    }
    .nav {
      grid-area: nav;
    }
    .menu-toggle {
      grid-area: toggle;
      justify-self: end;
      align-self: center;
      padding-bottom: 20px;
    }
    .menu-toggle button {
      all: initial;
      display: inline-block;
      cursor: pointer;
    }
    .menu-toggle .button {
      all: initial;
      display: inline-block;
      position: relative;
      width: 2.25rem;
      height: 2.25rem;
      background: var(--il-blue);
      color: white;
      text-transform: uppercase;
      border-radius: .25rem;
      cursor: pointer;
    }
    .menu-toggle .icon {
      position: absolute;
      left: .25rem;;
      top: .25rem;
      display: block;
      width: 1.75rem;
      height: 1.75rem;
    }
    .menu-toggle .icon svg {
      position: absolute;
      left: 0;
      top: 0;
      width: 100%;
      height: 100%;
      fill: currentColor;
    }
    .menu-toggle .label {
      position: absolute;
      top: 0;
      left: 0;
      display: block;
      width: 1px;
      height: 1px;
      overflow: hidden;
      text-indent: 300%;
      white-space: nowrap;
    }
    .menu {
      display: none;
      background: #E8E9EB;
    }
    .expanded.header .menu {
      display: block;
    }
    @media (min-width: 600px) {
      .compact.header .main {
        grid-template-columns: 30px auto 120px 30px;
        grid-template-rows: 63px auto;
        grid-template-areas: ". illinois illinois ." ". identity toggle .";
      }
      .illinois a {
        width: 445px;
      }
      .menu-toggle .button {
        width: auto;
      }
      .menu-toggle .label {
        position: relative;
        width: auto;
        height: auto;
        overflow: visible;
        text-indent: 0;
        padding: 0 .75rem 0 2.25rem;
        font: 600 1.25rem/2.25rem var(--il-font-sans);
      }
    }
    @media (min-width: 1200px) {
      .full.header .main {
        grid-template-columns: 30px 435px auto auto 355px 30px;
        grid-template-areas: ". illinois links links links ." ". identity identity identity search ." "nav nav nav nav nav nav";
      }
    }
  `);
customElements.define("il-header", j);
export {
  j as HeaderComponent
};