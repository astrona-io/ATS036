---
exam_objectives:
- Detect threats within physical infrastructure, apps, networks, data, users and workloads
---
# Count Failed Logins In An Application Log Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig is the file that tells kubectl, the Kubernetes command-line tool, which cluster to use and with which credentials. This lab runs in its own cluster, separate from the playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-036-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-036-lab-020-02-02" || exit 1
```

Keep this connection for the whole task. Every script of the lab refuses to run against another context.

The cluster cannot tell you who failed to log in. Only the application knows that, and it writes the fact to its standard output. The container runtime on the node stores that output in the container log, and `kubectl logs` reads it through the API server, which fetches it from the kubelet on that node. This task turns that log into four facts: how many logins failed, who was targeted, from which address, and whether the guessing worked.

## Count the failed logins

Start with the count, because it tells you whether there is anything to investigate. The option `-c` of `grep` prints the number of matching lines instead of the lines themselves:

```sh
kubectl -n starfleet-036-020-02-02 logs login-service | grep -c "login failed"
```

```text
8
```

The log has 8 failed logins. The number counts every line that contains `login failed`, for every user and every address. Use the exact phrase `login failed` as the pattern. A shorter pattern such as `login` also matches the `login ok` lines and gives a wrong count. This number is the value for `failedCount`.

A count alone does not show an attack. A user who mistypes a password once also produces a `login failed` line. To judge the count, you need to see the lines in order.

## Find the target and the source

Print the whole log. It is short, so you can read it from top to bottom:

```sh
kubectl -n starfleet-036-020-02-02 logs login-service
```

```text
service start port=8443
login failed user=lena src=10.0.0.41
login ok user=lena src=10.0.0.41
health check ok
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login failed user=admin src=10.0.0.23
login ok user=ops src=10.0.0.23
health check ok
service ready
```

Two kinds of failure appear. The user `lena` fails once from `10.0.0.41` and then logs in from the same address. That pattern is a normal mistyped password. The user `admin` fails many times in a row from `10.0.0.23`. Many failures for one account from one address in a short time is the pattern of automated password guessing, called a brute-force attack.

For a longer log, let the shell group the lines for you. The command below keeps only the failures, sorts them so that equal lines sit together, and lets `uniq -c` print each distinct line once with its count:

```sh
kubectl -n starfleet-036-020-02-02 logs login-service | grep "login failed" | sort | uniq -c
```

```text
      7 login failed user=admin src=10.0.0.23
      1 login failed user=lena src=10.0.0.41
```

The line with the highest count names the target user and the source address. These are the values for `targetUser` and `sourceAddress`. The source address is in the log only because this application writes it. Without the address, you could not tell one client from many.

## Check what happened after the failures

The most important question is whether the guessing worked. A successful login from the same address after many failures means the client may now hold a valid password. Filter the log for the source address. Add `--timestamps`, so that each line starts with the time the container runtime stored it:

```sh
kubectl -n starfleet-036-020-02-02 logs login-service --timestamps | grep "src=10.0.0.23"
```

```text
2026-11-22T20:41:29.459255285Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459258070Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459261176Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459264221Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459266716Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459268690Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459270333Z login failed user=admin src=10.0.0.23
2026-11-22T20:41:29.459272076Z login ok user=ops src=10.0.0.23
```

The last line from `10.0.0.23` is a `login ok`, and it names a different user, `ops`, not `admin`. So the client that guessed at `admin` then logged in as `ops`. That is the value for `successUser`.

The timestamps come from the container runtime, not from the application, so they show when each line reached the log, which is close to when it was written. All eight lines from `10.0.0.23` arrived within the same second, a few microseconds apart. No person types that fast, so a program sent these attempts. The times in your own lab differ.

## Record the finding

Write the four values into a ConfigMap. A ConfigMap is a Kubernetes object that stores key and value pairs as strings, so the count needs quotes in YAML. Save this as `configmap-login-findings.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: login-findings
  namespace: starfleet-036-020-02-02
data:
  failedCount: '8'
  targetUser: admin
  sourceAddress: 10.0.0.23
  successUser: ops
```

Apply it:

```sh
kubectl apply -f configmap-login-findings.yaml
```

Then check the result:

```sh
kubectl -n starfleet-036-020-02-02 get configmap login-findings -o jsonpath='{.data}{"\n"}'
```

```text
{"failedCount":"8","sourceAddress":"10.0.0.23","successUser":"ops","targetUser":"admin"}
```

The API server stored the four values as strings. The grader reads the live log of `login-service` again and compares each value with it, so the report must match the log, not only a fixed answer. Leave Pod `login-service` running. If its container restarts, the current log starts again and older lines are only in `kubectl logs --previous`.

You now know how to turn an application log into a finding: count with a precise pattern, group the failures by user and address, and look at what happened after them. The open question is how long such evidence lasts, because the node rotates container logs and a deleted Pod takes its log with it. After recording the result, remove this lab with `astrona destroy ats-036-lab-020-02-02`.

## Common pitfalls

> [!WARNING]
> - **Using a pattern that is too broad.** `grep -c login` also counts the `login ok` lines.
> - **Treating every failure as the attack.** One failure followed by a success from the same address is usually a mistyped password.
> - **Missing the success for another user.** After guessing, a client can log in as a different account. Filter by the source address, not only by the user.
> - **Writing the count as a number in YAML.** A ConfigMap value must be a string, so write `'8'` in quotes.
> - **Restarting the Pod.** A new container starts a new log, and the evidence moves to `--previous` or is lost.
