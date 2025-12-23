# TINAXI
(._.)

+-------------------+
|  Storage Engine   |  ← hash table / LSM / B+tree
+-------------------+
|   Command Layer   |  ← GET / SET / DEL / protocol
+-------------------+
|  Transport (TCP)  |  ← sockets, epoll, threads
+-------------------+

