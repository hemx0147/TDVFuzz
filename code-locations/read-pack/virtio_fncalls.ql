/**
 * @id virtio-fn-call
 * @name Function Call
 * @description find callers of virtio-related read functions and list functions along with their callers
 * @kind problem
 * @problem.severity warning
 * @tags Virtio
 * 			 Function
 */

import cpp

from FunctionCall call, string fname
where
  call.getTarget().getName() = fname and
  fname.regexpMatch(".*Virtio.*") and
  fname.regexpMatch(".*Read.*")
select call, call.getEnclosingFunction().getName() + " -> " + fname