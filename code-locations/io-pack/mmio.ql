/**
 * @id mmio
 * @name Mmio
 * @kind problem
 * @problem.severity warning
 * @tags Mmio
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Mmio.*Read.*") or
		target_name.regexpMatch(".*Read.*Mmio.*") or
		target_name.regexpMatch(".*Mmio.*Write.*") or
		target_name.regexpMatch(".*Write.*Mmio.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name