/**
 * @id cr
 * @name Cr
 * @kind problem
 * @problem.severity warning
 * @tags Cr
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Cr.*Read.*") or
		target_name.regexpMatch(".*Read.*Cr.*") or
		target_name.regexpMatch(".*Cr.*Write.*") or
		target_name.regexpMatch(".*Write.*Cr.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name