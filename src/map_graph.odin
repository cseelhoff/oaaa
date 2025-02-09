package oaaa

// import "core:fmt"
// import "core:net"
// import "core:encoding/json"
// import "core:strings"

// Node :: struct {
//     id: string,
//     group: int,
//     fixed_x: int,
//     fixed_y: int,
// }

// Link :: struct {
//     source: string,
//     target: string,
// }

// GraphData :: struct {
//     nodes: []Node,
//     links: []Link,
// }

// main :: proc() {
//     nodes := make([dynamic]Node)
//     defer delete(nodes)
    
//     // Create nodes for each vertex
//     for vertex in Vertices {
//         node := Node{
//             id = fmt.tprintf("%v", vertex),
//             group = 1,
//             fixed_x = vertex_positions[vertex].x,
//             fixed_y = vertex_positions[vertex].y,
//         }
//         append(&nodes, node)
//     }
    
//     links := make([dynamic]Link)
//     defer delete(links)
    
//     // Create links from edges
//     for edge in Edges {
//         link := Link{
//             source = fmt.tprintf("%v", edge[0]),
//             target = fmt.tprintf("%v", edge[1]),
//         }
//         append(&links, link)
//     }
    
//     // Convert to JSON
//     graph_data := GraphData{
//         nodes = nodes[:],
//         links = links[:],
//     }
    
//     // Create server
//     endpoint := net.Endpoint{
//         address = net.IP4_Loopback,
//         port = 8080,
//     }

//     server, err := net.listen_tcp(endpoint)
//     if err != nil {
//         fmt.eprintln("Failed to create server:", err)
//         return
//     }
//     defer net.close(server)
    
//     fmt.println("Server running at http://localhost:8080")
    
//     for {
//         client, _, accept_err := net.accept_tcp(server)
//         if accept_err != nil {
//             fmt.eprintln("Error accepting connection:", accept_err)
//             continue
//         }
        
//         // Handle request
//         buffer: [4096]byte
//         n, _ := net.recv(client, buffer[:])
//         request := string(buffer[:n])
        
//         response: string
//         if strings.contains(request, "GET /graph-data") {
//             json_data, err := json.marshal(graph_data)
//             if err != nil {
//                 fmt.eprintln("Error marshaling JSON:", err)
//                 response = "HTTP/1.1 500 Internal Server Error\r\n\r\n"
//             } else {
//                 response = fmt.tprintf("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n%s", string(json_data))
//             }
//         } else {
//             response = fmt.tprintf("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n%s", HTML)
//         }
        
//         net.send(client, transmute([]byte)response)
//         net.close(client)
//     }
// }

// HTML :: `<!DOCTYPE html>
// <html>
// <head>
//     <title>Graph Visualization</title>
//     <script src="https://d3js.org/d3.v7.min.js"></script>
//     <style>
//         body {
//             margin: 0;
//             overflow: hidden;
//         }
//         svg {
//             width: 100vw;
//             height: 100vh;
//         }
//         .node-label {
//             font-family: sans-serif;
//             font-size: 8px;
//             pointer-events: none;
//         }
//     </style>
// </head>
// <body>
//     <svg width="3500" height="2000"></svg>
//     <script>
//         async function fetchGraphData() {
//             const response = await fetch('/graph-data');
//             const data = await response.json();
            
//             // Store original positions
//             data.nodes.forEach(function(node) {
//                 node.originalX = node.fixed_x;
//                 node.originalY = node.fixed_y;
//                 // Start from original position but allow movement
//                 node.x = node.fixed_x;
//                 node.y = node.fixed_y;
//                 delete node.fixed_x;
//                 delete node.fixed_y;
//             });

//             const simulation = d3.forceSimulation(data.nodes)
//                 .force("link", d3.forceLink(data.links)
//                     .id(function(d) { return d.id; })
//                     .distance(100)
//                     .strength(0.003))
//                 .force("charge", d3.forceManyBody()
//                     .strength(-200)
//                     .distanceMax(200))
//                 .force("original", function(alpha) {
//                     return function(d) {
//                         const k = 0.3 * alpha;
//                         d.vx += (d.originalX - d.x) * k;
//                         d.vy += (d.originalY - d.y) * k;
//                     };
//                 })
//                 .force("collision", d3.forceCollide().radius(30))
//                 .alphaDecay(0.02)
//                 .velocityDecay(0.3);

//             const svg = d3.select("svg");
//             const g = svg.append("g");

//             svg.call(d3.zoom()
//                 .scaleExtent([0.1, 4])
//                 .on("zoom", function(event) {
//                     g.attr("transform", event.transform);
//                 }));

//             const link = g.append("g")
//                 .selectAll("line")
//                 .data(data.links)
//                 .join("line")
//                 .attr("stroke", "#999")
//                 .attr("stroke-opacity", 0.6)
//                 .attr("stroke-width", 2);

//             const node = g.append("g")
//                 .selectAll("g")
//                 .data(data.nodes)
//                 .join("g")
//                 .call(d3.drag()
//                     .on("start", dragstarted)
//                     .on("drag", dragged)
//                     .on("end", dragended));

//             node.append("circle")
//                 .attr("r", 5)
//                 .attr("fill", "#69b3a2");

//             node.append("text")
//                 .text(function(d) { return d.id; })
//                 .attr("x", 8)
//                 .attr("y", 3)
//                 .style("font-size", "8px");

//             simulation.on("tick", function() {
//                 link
//                     .attr("x1", function(d) { return d.source.x; })
//                     .attr("y1", function(d) { return d.source.y; })
//                     .attr("x2", function(d) { return d.target.x; })
//                     .attr("y2", function(d) { return d.target.y; });

//                 node
//                     .attr("transform", function(d) { 
//                         return "translate(" + d.x + "," + d.y + ")";
//                     });
//             });

//             function dragstarted(event, d) {
//                 if (!event.active) simulation.alphaTarget(0.3).restart();
//                 d.fx = d.x;
//                 d.fy = d.y;
//             }

//             function dragged(event, d) {
//                 d.fx = event.x;
//                 d.fy = event.y;
//             }

//             function dragended(event, d) {
//                 if (!event.active) simulation.alphaTarget(0);
//                 d.fx = null;
//                 d.fy = null;
//             }
//         }

//         fetchGraphData();
//     </script>
// </body>
// </html>`