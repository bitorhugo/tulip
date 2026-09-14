module Tulip

const PortType = Symbol

abstract type Error end

struct CompositionError <: Error
    kind::Symbol # :type, :port, etc.
    expected::Any
    got::Any
end

CompositionError(kind) = CompositionError(kind,
                                          nothing,
                                          nothing)

struct PortRef
    nodeid::Int
    portname::Symbol
end

struct Port
    name::Symbol
    type::PortType
end

struct Declaration
    inputs::Vector{Port}
    outputs::Vector{Port}
end

decl(ins, outs) = Declaration([Port(n, t) for (n, t) in ins],
                               [Port(n, t) for (n, t) in outs])

struct Component
    name::Symbol
    decl::Declaration
    impl::Function
end

struct Composition
    nodes::Vector{Component}
    edges::Vector{Pair{PortRef,PortRef}}
end

Composition(nodes, edges::Vector{Pair{Tuple{Int64, Symbol}, Tuple{Int64, Symbol}}}) =
    Composition(nodes,
                [PortRef(from...) => PortRef(to...)
                 for (from, to) in edges])

function evaluate(c::Composition)
    order = toposort(c)
    outputs = Vector{Any}(undef, length(c.nodes))

    for n in order
        inp = c.nodes[n].decl.inputs
        args = []

        for port in inp
            idx = findfirst((e) -> e.second.portname == port.name, c.edges)
            push!(args, outputs[c.edges[idx].first.nodeid])
        end

        outputs[n] = c.nodes[n].impl(args...)
    end

    return outputs
end

function toposort(c::Composition)
    l = length(c.nodes)
    visited = fill(false, l)
    order = Int[]

    function visit(n)
        visited[n] && return
        visited[n] = true
        for e in c.edges
            if e.second.nodeid == n
                visit(e.first.nodeid)
            end
        end
        push!(order, n)
    end

    for n in 1:l
        visit(n)
    end

    return order
end

function typecheck(c::Composition)
    visited = fill(false, length(c.nodes))

    for e in c.edges
        src_ref, dst_ref = e

        visited[src_ref.nodeid] = true


        if visited[dst_ref.nodeid]
            return CompositionError(:cyclic,
                                    src_ref.nodeid,
                                    dst_ref.nodeid)
        end

        src_node = c.nodes[src_ref.nodeid]
        dst_node = c.nodes[dst_ref.nodeid]

        src_outputs = src_node.decl.outputs
        dst_inputs = dst_node.decl.inputs

        i = findfirst((p) -> p.name == src_ref.portname,
                      src_outputs)
        j = findfirst((p) -> p.name == dst_ref.portname,
                      dst_inputs)

        if isnothing(i)
            return CompositionError(:port, src_ref.portname, i)
        end

        if isnothing(j)
            return CompositionError(:port, dst_ref.portname, j)
        end

        src_type = src_outputs[i].type
        dst_type = dst_inputs[j].type

        if src_type != dst_type
            return CompositionError(:type, dst_type, src_type)
        end
    end

    for n in c.nodes
        for inp in n.decl.inputs # components with no inputs don't error

            i = findfirst((e) -> e.second.portname == inp.name, c.edges)

            if isnothing(i)
                return CompositionError(:dangling, inp.name, i)
            end
        end
    end

    return true
end

# Export

for sym in names(@__MODULE__; all=true)
    if sym !== Symbol(@__MODULE__) && !startswith(string(sym), "#")
        @eval export $sym
    end
end

end # Tulip
