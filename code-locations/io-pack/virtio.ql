/**
 * @id virtio
 * @name Virtio
 * @kind problem
 * @problem.severity warning
 * @tags Virtio
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Virtio.*Read.*") or
		target_name.regexpMatch(".*Read.*Virtio.*") or
		target_name.regexpMatch(".*Virtio.*Write.*") or
		target_name.regexpMatch(".*Write.*Virtio.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name