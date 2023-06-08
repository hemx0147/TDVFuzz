/**
 * @id virtio-macro
 * @name Macro Definition
 * @description find definitions of macros that use virtio-related read functions
 * @kind problem
 * @problem.severity warning
 * @tags Macro
 *       Virtio
 */

import cpp

from Macro m, string mname
where
  m.getName() = mname and
  mname.regexpMatch(".*VIRTIO.*") and
  mname.regexpMatch(".*READ.*")
select m, mname
