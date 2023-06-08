/**
 * @id virtio-macro-fn-call
 * @name Macro Function
 * @description find invocations of virtio read macros and list which functions they use
 * @kind problem
 * @problem.severity warning
 * @tags Macro
 *       Virtio
 */

import cpp

from MacroInvocation m, Expr e, string mname
where
  m.getMacroName() = mname and
  mname.regexpMatch(".*VIRTIO.*") and
  mname.regexpMatch(".*READ.*") and
  m.getExpr() = e
select e, mname + " -> " + e.getChild(0).toString()