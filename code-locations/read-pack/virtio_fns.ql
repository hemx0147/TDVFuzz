/**
 * @id virtio-fn
 * @name Function Definition
 * @description find definitions for virtio-related read functions
 * @kind problem
 * @problem.severity warning
 * @tags Virtio
 * 			 Function
 */

import cpp

from Function fn, string fname
where
	fn.getName() = fname and
	fname.regexpMatch(".*Virtio.*") and
	fname.regexpMatch(".*Read.*")
select fn, fname