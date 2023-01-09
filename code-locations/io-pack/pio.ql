/**
 * @id pio
 * @name Pio
 * @kind problem
 * @problem.severity warning
 * @tags Pio
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Pio.*Read.*") or
		target_name.regexpMatch(".*Read.*Pio.*") or
		target_name.regexpMatch(".*Pio.*Write.*") or
		target_name.regexpMatch(".*Write.*Pio.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name