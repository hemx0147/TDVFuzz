/**
 * @id virtio-macro-call
 * @name Macro Call
 * @description find invocations of virtio config read macro and list the macro along with its caller
 * @kind problem
 * @problem.severity warning
 * @tags Macro
 *       Virtio
 */

import cpp

from MacroInvocation m, string mname
where
  m.getMacroName() = mname and
  mname = "VIRTIO_CFG_READ"
select m, m.getEnclosingFunction().getName() + " -> " + mname
