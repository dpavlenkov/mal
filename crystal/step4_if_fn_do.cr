#! /usr/bin/env crystal run

require "./readline"
require "./reader"
require "./printer"
require "./types"
require "./env"
require "./core"

# Note:
# Employed downcase names because Crystal prohibits uppercase names for methods

def eval_error(msg)
  raise Mal::EvalException.new msg
end

def func_of(env, binds, body)
  -> (args : Array(Mal::Type)) {
    new_env = Mal::Env.new(env, binds, args)
    eval(body, new_env)
  } as Mal::Func
end

def eval_ast(ast, env)
  return ast.map{|n| eval(n, env) as Mal::Type} if ast.is_a?(Mal::List)

  val = ast.val

  Mal::Type.new case val
  when Mal::Symbol
    if e = env.get(val.val)
      e
    else
      eval_error "'#{val.val}' not found"
    end
  when Mal::List
    val.each_with_object(Mal::List.new){|n, l| l << eval(n, env)}
  when Mal::Vector
    val.each_with_object(Mal::Vector.new){|n, l| l << eval(n, env)}
  when Mal::HashMap
    val.each{|k, v| val[k] = eval(v, env)}
    val
  else
    val
  end
end

def read(str)
  read_str str
end

def eval(ast, env)
  list = ast.val
  unless list.is_a?(Mal::List)
    return eval_ast(ast, env)
  end

  return Mal::Type.new(Mal::List.new) if list.empty?

  head = list.first.val

  Mal::Type.new case head
  when Mal::Symbol
    case head.val
    when "def!"
      eval_error "wrong number of argument for 'def!'" unless list.size == 3
      a1 = list[1].val
      eval_error "1st argument of 'def!' must be symbol" unless a1.is_a?(Mal::Symbol)
      env.set(a1.val, eval(list[2], env))
    when "let*"
      eval_error "wrong number of argument for 'def!'" unless list.size == 3

      bindings = list[1]
      eval_error "1st argument of 'let*' must be list or vector" unless bindings.is_a?(Array)
      eval_error "size of binding list must be even" unless bindings.size.even?

      new_env = Mal::Env.new env
      bindings.each_slice(2) do |binding|
        name, value = binding
        eval_error "name of binding must be specified as symbol" unless name.is_a?(Mal::Symbol)
        new_env.set(name.val, eval(value, new_env))
      end

      eval(list[2], new_env)
    when "do"
      list.shift(1)
      eval_ast(list, env).last
    when "if"
      cond = eval(list[1], env)
      case cond
      when Nil
        list.size >= 4 ? eval(list[3], env) : nil
      when false
        list.size >= 4 ?  eval(list[3], env) : nil
      else
        eval(list[2], env)
      end
    when "fn*"
      # Note:
      # If writing lambda expression here directly, compiler will fail to infer type of 'list'. (Error 'Nil for empty?')
      func_of(env, list[1], list[2])
    else
      f = eval_ast(list.first, env).val
      eval_error "expected function symbol as the first symbol of list" unless f.is_a?(Mal::Func)
      list.shift(1)
      f.call eval_ast(list, env)
    end
  else
    f = eval(list.first, env).val
    eval_error "expected function symbol as the first symbol of list" unless f.is_a?(Mal::Func)
    list.shift(1)
    f.call eval_ast(list, env)
  end
end

def print(result)
  pr_str(result, true)
end

def rep(str)
  print(eval(read(str), $repl_env))
end

$repl_env = Mal::Env.new nil
Mal::NS.each{|k,v| $repl_env.set(k, Mal::Type.new(v))}

while line = my_readline("user> ")
  begin
    puts rep(line)
  rescue e
    STDERR.puts e
  end
end
