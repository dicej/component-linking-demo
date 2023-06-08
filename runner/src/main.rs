use {
    anyhow::{anyhow, Result},
    clap::Parser,
    std::path::PathBuf,
    tokio::fs,
    wasmtime::{
        component::{Component, Linker},
        Config, Engine, Store,
    },
    wasmtime_wasi::preview2::{wasi::command, Table, WasiCtx, WasiCtxBuilder, WasiView},
};

#[derive(Parser)]
pub struct Options {
    component: PathBuf,
}

struct Ctx {
    wasi: WasiCtx,
    table: Table,
}
impl WasiView for Ctx {
    fn ctx(&self) -> &WasiCtx {
        &self.wasi
    }
    fn ctx_mut(&mut self) -> &mut WasiCtx {
        &mut self.wasi
    }
    fn table(&self) -> &Table {
        &self.table
    }
    fn table_mut(&mut self) -> &mut Table {
        &mut self.table
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let options = Options::parse();

    let mut config = Config::new();
    config.wasm_component_model(true);
    config.async_support(true);

    let engine = Engine::new(&config)?;
    let mut linker = Linker::new(&engine);
    command::add_to_linker(&mut linker)?;
    linker
        .instance("test:test/test")?
        .func_wrap("bar", |_store, (v,): (i32,)| Ok((v + 7,)))?;
    let mut table = Table::new();
    let wasi = WasiCtxBuilder::new().inherit_stdio().build(&mut table)?;
    let mut store = Store::new(&engine, Ctx { wasi, table });
    let instance = linker
        .instantiate_async(
            &mut store,
            &Component::new(&engine, &fs::read(&options.component).await?)?,
        )
        .await?;
    let func = instance
        .exports(&mut store)
        .instance("test:test/test")
        .ok_or_else(|| anyhow!("instance `test:test/test` not found"))?
        .typed_func::<(i32,), (i32,)>("bar")?;

    assert_eq!(87, func.call_async(&mut store, (7,)).await?.0);

    Ok(())
}
