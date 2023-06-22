use {
    anyhow::{anyhow, Result},
    cap_std::fs::Dir,
    clap::Parser,
    tokio::fs,
    wasmtime::{
        component::{Component, Linker},
        Config, Engine, Store,
    },
    wasmtime_wasi::preview2::{
        wasi::command, DirPerms, FilePerms, Table, WasiCtx, WasiCtxBuilder, WasiView,
    },
};

fn parse_mapdir(s: &str) -> Result<(String, String)> {
    if let Some((guest_dir, host_dir)) = s.split_once("::") {
        Ok((guest_dir.into(), host_dir.into()))
    } else {
        Err(anyhow!(
            "expected string of form GUEST_DIR::HOST_DIR; got {s}"
        ))
    }
}

fn parse_env(s: &str) -> Result<(String, String)> {
    if let Some((name, value)) = s.split_once("=") {
        Ok((name.into(), value.into()))
    } else {
        Err(anyhow!("expected string of form NAME=VALUE; got {s}"))
    }
}

#[derive(Parser)]
pub struct Options {
    component: String,

    #[clap(long, value_name = "GUEST_DIR::HOST_DIR", value_parser = parse_mapdir)]
    mapdir: Vec<(String, String)>,

    #[clap(long, value_name = "NAME=VALUE", value_parser = parse_env)]
    env: Vec<(String, String)>,
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
    let mut wasi = WasiCtxBuilder::new().inherit_stdio();

    for (guest_dir, host_dir) in options.mapdir {
        wasi = wasi.push_preopened_dir(
            Dir::from_std_file(std::fs::File::open(host_dir)?),
            DirPerms::all(),
            FilePerms::all(),
            guest_dir,
        );
    }

    for (name, value) in options.env {
        wasi = wasi.push_env(name, value);
    }

    let wasi = wasi.build(&mut table)?;
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

    assert_eq!(138, func.call_async(&mut store, (7,)).await?.0);

    Ok(())
}
