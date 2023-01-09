/**
 * @id msr
 * @name Msr
 * @kind problem
 * @problem.severity warning
 * @tags Msr
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Msr.*Read.*") or
		target_name.regexpMatch(".*Read.*Msr.*") or
		target_name.regexpMatch(".*Msr.*Write.*") or
		target_name.regexpMatch(".*Write.*Msr.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name