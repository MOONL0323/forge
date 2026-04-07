# /fix-ci — Fix CI Failure

Analyzes the most recent CI failure, fixes the root cause, and creates a PR.

## Usage

```
/fix-ci                    # Auto-detect from environment
/fix-ci --logs /path       # Use specific log file
/fix-ci --job "build"      # Specify job name
/fix-ci --no-pr            # Fix but don't create PR
```

## What it does

1. Reads failure logs (from `/tmp/failed_logs.txt` or GitHub API)
2. Classifies failure type (compile / test / lint / env)
3. Identifies root cause with file:line location
4. Applies minimal fix
5. Verifies build/test/lint pass
6. Creates PR to the target branch

## Examples

```
/fix-ci
/fix-ci --job "unit-tests"
/fix-ci --logs ./ci-output.log --no-pr
```

## Notes

- Environment failures (timeout, network) are marked `skip` — no code changes made
- Maximum 3 auto-fix attempts per branch before requiring manual intervention
- Only modifies files directly related to the failure
