/**
 * @id pciio
 * @name Pciio
 * @kind problem
 * @problem.severity warning
 * @tags Pciio
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Pciio.*Read.*") or
		target_name.regexpMatch(".*Read.*Pciio.*") or
		target_name.regexpMatch(".*Pciio.*Write.*") or
		target_name.regexpMatch(".*Write.*Pciio.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name