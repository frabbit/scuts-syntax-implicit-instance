

class Test {
	public static function main () {
		simple.Simple.main();
		dependency.Dependency.main();
		prop.Prop.main();
		multiprops.MultiProps.main();
		either.EitherTest.main();
		thisdep.ThisDep.main();
		Expect.reportAndExit();
	}
}