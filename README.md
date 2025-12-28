# TINAXI
(._.)

```
+-------------------+
|  Storage Engine   |  ← hash table / LSM / B+tree
+-------------------+
|   Command Layer   |  ← GET / SET / DEL / protocol
+-------------------+
|  Transport (TCP)  |  ← sockets, epoll, threads
+-------------------+
```

## TCP:
- Simple text-based protocol
- Commands: GET, SET, DEL
- Responses: OK, ERROR, VALUE
- Example:
  - Client: `SET key value

## Problems
TCP no is commands, bytes limit for kernel

