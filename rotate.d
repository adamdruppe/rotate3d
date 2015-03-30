import simpledisplay;
import arsd.joystick;
import arsd.simpleaudio;

import arsd.gamehelpers;

/*
	Awesome controls:

		thrust
		look

		juke
*/

/*
http://www.opengl-tutorial.org/beginners-tutorials/tutorial-5-a-textured-cube/ 
http://www.opengl-tutorial.org/beginners-tutorials/tutorial-7-model-loading/ 
*/

import std.math;

bool[Key] keyboardState;

bool keyIsDown(Key key) {
	if(auto ptr = key in keyboardState)
		return *ptr;
	return false;
}

class Actor {
	Actor next; // they are a linked list

	bool inactive; // inactive things can be removed from the list by the main loop

	double x, y, z = 0.0;
	double dx = 0.0, dy = 0.0, dz = 0.0;

	// since this is based on the 2d, from the starting position,
	// rx is roll, ry is pitch, and rz is yaw
	// but these are global coordinates so that won't necessarily remain true
	double rx = 0.0, ry = 0.0, rz = 0.0; // in degrees

	// maybe these SHOULD be relative to the ship...
	double drx = 0.0, dry = 0.0, drz = 0.0;

	final double radiansTheta() {
		return rz / 180.0 * PI;
	}

	version(rotate_3d)
	final double radiansPhi() {
		return rx / 180.0 * PI;
	}

	void update() {
		x += dx;
		y += dy;
		z += dz;

		rx += drx;
		ry += dry;
		rz += drz;

		if(rx >= 360)
			rx -= 360;
		if(ry >= 360)
			ry -= 360;
		if(rz >= 360)
			rz -= 360;

		if(rx < 0)
			rx += 360;
		if(ry < 0)
			ry += 360;
		if(rz < 0)
			rz += 360;

	}

	abstract void draw();

	final void drawOnScreen() {
		glPushMatrix();

		glTranslatef(x, y, z);

		version(rotate_3d) {
			glRotatef(rz, 0.0, 0.0, 1.0);
			glRotatef(ry, 0.0, 1.0, 0.0);
			glRotatef(rx, 1.0, 0.0, 0.0);
		} else {
			glRotatef(rz, 0.0, 0.0, 1.0);
		}

		draw();

		glPopMatrix();
	}
}

class ReferencePoint : Actor {
	override void update() {}
	override void draw() {}
}

class NavigationBeacon : Actor {
	this(float x, float y, float z) {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	override void draw() {
		glColor4f(0.0, 1.0, 0.0, 128);

		glScalef(0.1, 0.1, 0.1);

		glBegin(GL_TRIANGLE_FAN);

		auto size = 1;
		glVertex3f(0, 0, size);
		glVertex3f(-size, -size, 0);
		glVertex3f(-size, size, 0);
		glVertex3f(size, -size, 0);
		glVertex3f(-size, -size, 0);
		glEnd();

		glColor4f(1.0, 1.0, 0.0, 128);

		glBegin(GL_TRIANGLE_FAN);
		glVertex3f(0, 0, -size);
		glVertex3f(-size, -size, 0);
		glVertex3f(-size, size, 0);
		glVertex3f(size, -size, 0);
		glVertex3f(-size, -size, 0);
		glEnd();

	}
	override void update() {}
}

class Ship : Actor {
	version(rotate_3d)
	this(double x, double y, double z) {
		this.x = x;
		this.y = y;
		this.z = z;
	}
	else
	this(double x, double y) {
		this.x = x;
		this.y = y;
	}

	int life = 100;
	int torpedoEnergy = 100;
	int fuel = 1000;


	int thrustLeftCounter;
	int thrustRightCounter;
	int thrustForwardCounter;

	final float rotationValue(int intensity) {
		intensity /= 1000;
		// 32 is the max... cubed is 32k
		intensity = intensity * intensity * intensity; // cube to give more precision control at low levels

		return 0.00003 * intensity;
	}

	void thrustLeft(short intensity) {
		if(fuel > 2) {
			fuel -= 2;
			// FIXME
			drz -= rotationValue(intensity);

			thrustLeftCounter = 4;
		}
	}

	void thrustRight(short intensity) {
		if(fuel > 2) {
			fuel -= 2;
			// FIXME
			drz += rotationValue(intensity);

			thrustRightCounter = 4;
		}
	}

	void thrustUp(short intensity) {
		dry -= rotationValue(intensity);
	}

	void thrustDown(short intensity) {
		dry += rotationValue(intensity);
	}

	void thrustForward() {
		if(fuel > 8) {
			fuel -= 8;
			version(rotate_3d)
			auto thrust = 0.01;
			else
			auto thrust = 0.4;

			version(rotate_3d) {

				float tx, ty, tz;
				this.getVector(1, 0, 0, tx, ty, tz);
				dx += thrust * tx;
				dy += thrust * ty;
				dz += thrust * tz;
			} else {
				dx += thrust * cos(radiansTheta);
				dy += thrust * sin(radiansTheta);
			}

			thrustForwardCounter = 4;
		}
	}

	void thrustBackward() {
		if(fuel > 4) {
			fuel -= 4;
			version(rotate_3d)
			auto thrust = 0.01;
			else
			auto thrust = 0.4;

			thrust /= 2;

			version(rotate_3d) {

				float tx, ty, tz;
				this.getVector(1, 0, 0, tx, ty, tz);
				dx -= thrust * tx;
				dy -= thrust * ty;
				dz -= thrust * tz;
			} else {
				dx -= thrust * cos(radiansTheta);
				dy -= thrust * sin(radiansTheta);
			}
		}
	}

	void fire() {
		if(torpedoEnergy >= 25) {
			torpedoEnergy -= 25;
			auto torp = new Torpedo(this);
		}
	}

	void getVector(float x, float y, float z, out float xp, out float yp, out float zp) {
		rotateAboutAxis(
			rx / 180 * PI,
			x, y, z,
			1, 0, 0,
			x, y, z);
		rotateAboutAxis(
			ry / 180 * PI,
			x, y, z,
			0, 1, 0,
			x, y, z);
		rotateAboutAxis(
			rz / 180 * PI,
			x, y, z,
			0, 0, 1,
			x, y, z);

		xp = x;
		yp = y;
		zp = z;
	}

	override void update() {
		if(this.torpedoEnergy < 100)
			this.torpedoEnergy++;
		if(this.fuel < 1000)
			this.fuel++;
		super.update();

		/* up vector rotated by the angles too i guess */

		version(rotate_3d) {} else
		if(x < 10 || y < 10 || x > 1034 || y > 778) {
			x = 500;
			y = 500;
			dx = 0;
			dy = 0;
			dθ = 0;
		}
	}

	override void draw() {
		glColor3f(1.0, 1.0, 1.0);

		version(rotate_3d)
		enum size = 0.5;
		else
		enum size = 10;

		glBegin(GL_LINE_LOOP);

		/*
		glVertex2f(0, 0);
		glVertex2f(-size, -size);
		glVertex2f(size, 0);
		glVertex2f(-size, size);
		*/

		glColor3f(0.0, 1.0, 0.0);
		glVertex3f(0, 0, 0);
		glColor3f(0.0, 0.0, 1.0);
		glVertex3f(-size, -size, 0);
		glColor3f(1.0, 1.0, 1.0);
		glVertex3f(size, 0, 0);
		glColor3f(0.0, 0.0, 1.0);
		glVertex3f(-size, size, 0);

		glEnd();

		glBegin(GL_LINE_LOOP);
		glColor3f(1.0, 0, 0);
		glVertex3f(0, 0, 0.01);
		glVertex3f(-size, -size, 0.01);
		glVertex3f(size, 0, 0.01);
		glVertex3f(-size, size, 0.01);
		glEnd();

		glBegin(GL_QUADS);
		glColor3f(1.0, 0, 0);
		glVertex3f(-size, -size, 0.1);
		glVertex3f(-size, -size, -0.1);
		glVertex3f(-size, size, -0.1);
		glVertex3f(-size, size, 0.1);
		glEnd();

		glBegin(GL_QUADS);
		glColor3f(0, 0, 1.0);
		glVertex3f(-size-.01, -size, 0.1);
		glVertex3f(-size-.01, -size, -0.1);
		glVertex3f(-size-.01, size, -0.1);
		glVertex3f(-size-.01, size, 0.1);
		glEnd();

		if(thrustLeftCounter) {
			glBegin(GL_LINES);

			glColor3f(1.0, 0.2, 0.7);

			glVertex2f(size, 0);
			glVertex2f(size, size / 2);

			glVertex2f(-size, -size);
			glVertex2f(-size, -size + -size/2);

			glEnd();

			thrustLeftCounter--;
		}

		if(thrustRightCounter) {
			glBegin(GL_LINES);

			glColor3f(1.0, 0.2, 0.7);

			glVertex2f(size, 0);
			glVertex2f(size, -size / 2);

			glVertex2f(-size, size);
			glVertex2f(-size, size + size/2);

			glEnd();

			thrustRightCounter--;
		}

		if(thrustForwardCounter) {
			glBegin(GL_LINES);

			glColor3f(1.0, 0.2, 0.7);

			glVertex2f(0, 0);
			glVertex2f(-size, -size / 4);

			glVertex2f(0, 0);
			glVertex2f(-size, size / 4);

			glVertex2f(0, 0);
			glVertex2f(-size, 0);

			glEnd();

			thrustForwardCounter--;

		}

		/+
		if(1 /* shields up */) {
			glBegin(GL_LINE_LOOP);

			glColor3f(0, 1.0, 1.0);

			enum ssize = 16;

			glVertex2f(ssize, 0);
			glVertex2f(ssize / 2, ssize);
			glVertex2f(-ssize / 2, ssize);
			glVertex2f(-ssize, 0);
			glVertex2f(-ssize / 2, -ssize);
			glVertex2f(ssize / 2, -ssize);

			glEnd();
		}
		+/


		//glRotatef(-rz, 0.0, 0.0, 1.0);
		//version(rotate_3d)
			//glRotatef(-rx, 0.0, 1.0, 0.0);

		auto statPos = 6;

		void drawStatBar(float r, float g, float b, float value, float maxValue) {
			statPos++;
			glBegin(GL_QUADS);
			glColor3f(r, g, b);

			auto length = value / maxValue * size * 2;

			glVertex2f(-size, size + statPos);
			glVertex2f(length, size + statPos);
			glVertex2f(length, size + statPos + 2);
			glVertex2f(-size, size + statPos + 2);

			glEnd();
			statPos += 2;
		}

		// life
		drawStatBar(0, 1.0, 0, life, 100);

		// torpedo power
		drawStatBar(
			1.0,
			0.20 * torpedoEnergy / 25,
			0.20 * torpedoEnergy / 25,
			torpedoEnergy,
			100);

		// fuel
		drawStatBar(0, 1.0, 1.0, fuel, 1000);
	}
}

class Torpedo : Actor {
	this(Ship firedFrom) {
		this.x = firedFrom.x;
		this.y = firedFrom.y;
		this.z = firedFrom.z;

		double speed = 8;

		version(rotate_3d) {
			speed = 0.28;
			float sx, sy, sz;
			firedFrom.getVector(1, 0, 0, sx, sy, sz);
			dx = firedFrom.dx + speed * sx;
			dy = firedFrom.dy + speed * sy;
			dz = firedFrom.dz + speed * sz;
		} else {
			this.dx = firedFrom.dx + speed * cos(firedFrom.radiansTheta);
			this.dy = firedFrom.dy + speed * sin(firedFrom.radiansTheta);
		}

		this.drx = 12;
		this.dry = 12;
		this.drz = 12;

		this.next = firedFrom.next;
		firedFrom.next = this;
	}

	int life = 2000 / 8; // just setting it to a ballpark number where it will no longer be on the screen anyway

	override void update() {
		this.life--;
		if(this.life <= 0)
			this.inactive = true;
		else
			super.update();
	}

	override void draw() {
		glColor3f(1.0, 1.0, 0);

		version(rotate_3d)
		auto size = 0.1;
		else
		auto size = 3;

		glBegin(GL_POLYGON);

		glVertex3f(0, size, 0.1);
		glVertex3f(size/2, -size, 0.0);
		glVertex3f(-size, size/2, -0.1);
		glVertex3f(size, size/2, 0.0);
		glVertex3f(-size/2, -size, 0.1);

		glEnd();
	}
}

void go2d() {
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, 1024, 768, 0, 0, 1);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glDisable(GL_DEPTH_TEST);
	glEnable(GL_TEXTURE_2D);
}

void go3d() {
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	// glFrustum(0, 1024, 768, 0, -10, 10);

	auto w = 1024;
	auto h = 768;

	gluPerspective(80.0, cast(double) w / h, 0.5, 1000.0);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glEnable(GL_TEXTURE_2D);

	gluLookAt(0, 0, -4, 0, 0, 0, 0, 1, 0);
}

void main() {
	auto window = new SimpleWindow(1024, 768, "Rotate 14!!!", OpenGlOptions.yes);

	auto root = new ReferencePoint();

	import stb_truetype;
	static import std.file;
	auto font = TtfFont(cast(ubyte[]) import("sans-serif.ttf"));

	version(rotate_3d)
		auto ship = new Ship(0, 0, 0.0);
	else
		auto ship = new Ship(500, 500);

	void addItem(Actor actor) {
		auto n = root.next;
		root.next = actor;
		actor.next = n;
	}

	addItem(ship);

	foreach(x; 1 .. 10) {
		addItem(new NavigationBeacon(-1, x, 0));
		addItem(new NavigationBeacon(1, x, 0));
	}

	addItem(new Ship(12, 45, 2));

	ship.dx = 0; //0.04;
	ship.dy = 0; // 0.04;

	ship.rz = 90;

	window.setAsCurrentOpenGlContext();

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glClearColor(0,0,0,0);
	glDepthFunc(GL_LEQUAL);

	OpenGlTexture[string] textTextures;
	OpenGlTexture getText(string text) {
		if(auto t = text in textTextures)
			return *t;
		auto t = new OpenGlTexture(&font, 16, text);
		textTextures[text] = t;
		return t;
	}

	float f = 0.0;

	version(rotate_3d)
		go3d();
	else
		go2d();

	bool firstPersonViewMode = true;

	window.redrawOpenGlScene = delegate() {
		Actor obj = root;
		Actor previous;
		while(obj) {
			obj.update();
			if(obj.inactive) {
				previous.next = obj.next;
			} else {
				previous = obj;
			}

			obj = obj.next;
		}

		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_ACCUM_BUFFER_BIT);

	version(rotate_3d) {
	glLoadIdentity();
	/*
	// trying for third person...
	gluLookAt(
		cameraX, cameraY, cameraZ,
		// looking at vector, x,y,z
		ship.x, ship.y, ship.z, // and looks at the ship

		upX, upY, upZ
		// and rotates with the ship - this is up, perpendicular to the direction of thrust
		//cos(rt) * sin(rp),
		//sin(rt) * sin(rp),
		//cos(rp)
		//0
	);
	*/

	/*
	import std.stdio;
	writeln( cameraX, " ",  cameraY, " ", cameraZ);
	*/
	if(firstPersonViewMode != keyIsDown(Key.A)) {
		float cameraX, cameraY, cameraZ;
		float upX, upY, upZ;

		ship.getVector(1, 0, 0, cameraX, cameraY, cameraZ);
		ship.getVector(0, 0, -1, upX, upY, upZ);

		gluLookAt(
			ship.x, ship.y, ship.z,
			ship.x + cameraX, ship.y + cameraY, ship.z + cameraZ,
			upX, upY, upZ
		);
	} else

	// follow the ship, fixed angle
	gluLookAt(
		ship.x, ship.y, ship.z - 35,
		ship.x, ship.y, ship.z,
		0.0, 1.0, 0);
	/*
	// fixed camera (works for the 2d overview but sucks for 3d, you get lost)
	gluLookAt(
		0, 0, 0 - 35,
		0, 0, 0,
		0.0, 1.0, 0);
	*/

	//glTranslatef(-cameraX, -cameraY, -cameraZ);
	//glRotatef(-ship.rz, 0.0, 0.0, 1.0);
	//glRotatef(ship.rx, 0.0, 1.0, 0.0);


	}

	/*
	glColor3f(1, 1, 1);
	// reference point stars
	glBegin(GL_POINTS);
	foreach(i; 0 .. 10)
	foreach(i2; 0 .. 10)
		glVertex3f(i * 10, i2 * 10, ship.z+ 800);

	glEnd();
	*/


		// this works, I can draw 3d stuff then go 2d and draw a 2d overlay on top of it
		version(rotate_3d) {
			//go3d();
			glPushMatrix();
			glTranslatef(4.0, 0, 0.0);
			glRotatef(f, 1, 0, 0);
			f += 4.4;

			glBegin(GL_TRIANGLES); 
			// base of the pyramid 
			glColor3f(1, 0, 0); glVertex3f(0.5, -0.5, 0); 
			glColor3f(0, 1, 0); glVertex3f(0, 0.5, 0); 
			glColor3f(0, 0, 1); glVertex3f(-0.5, -0.5, 0); 
			// the other three sides connect to the top 
			glColor3f(1, 1, 1); glVertex3f(0, 0, 0.5); 
			glColor3f(0, 1, 0); glVertex3f(0, 0.5, 0); 
			glColor3f(0, 0, 1); glVertex3f(-0.5, -0.5, 0); 
			glColor3f(1, 0, 0); glVertex3f(0.5, -0.5, 0); 
			glColor3f(1, 1, 1); glVertex3f(0, 0, 0.5); 
			glColor3f(0, 0, 1); glVertex3f(-0.5, -0.5, 0); 
			glColor3f(1, 1, 1); glVertex3f(0, 0, 0.5); 
			glColor3f(1, 0, 0); glVertex3f(0.5, -0.5, 0); 
			glColor3f(0, 1, 0); glVertex3f(0, 0.5, 0); 
			glEnd();

			glPopMatrix();

			//go2d();
		}

		obj = root;
		while(obj) {
			obj.drawOnScreen();
			obj = obj.next;
		}

		version(rotate_3d) {
			go2d();
			// go 2d to draw the instruments overlay

			import std.string;
			auto texture = getText(format("%0.3f", ship.x));
			texture.draw(Point(0, 0));
			texture = getText(format("%0.3f", ship.y));
			texture.draw(Point(0, 16));
			texture = getText(format("%0.3f", ship.z));
			texture.draw(Point(0, 32));

			texture = getText(format("%0.3f", ship.rx));
			texture.draw(Point(0, 48));
			texture = getText(format("%0.3f", ship.ry));
			texture.draw(Point(0, 64));
			texture = getText(format("%0.3f", ship.rz));
			texture.draw(Point(0, 80));



			go3d();
		}
	};

	auto players = enableJoystickInput(0, -1);

	auto timerEvent = delegate () {
		auto joy = getJoystickUpdate(0);

		enum digitalThrust = 12800;

		auto axis = joy.axisPosition(Axis.horizontalDpad, digitalThrust);

		if(!axis) {
			if(keyIsDown(Key.Left))
				ship.thrustLeft(digitalThrust);
			if(keyIsDown(Key.Right))
				ship.thrustRight(digitalThrust);
		} else {
			if(axis < 0)
				ship.thrustLeft(-axis);
			else
				ship.thrustRight(axis);

		}

		if(joy.buttonWasJustPressed(Button.r1))
			firstPersonViewMode = !firstPersonViewMode;

		if(keyIsDown(Key.S)) {
			ship.x = 0;
			ship.y = 0;
			ship.z = 0;
		}
		if(keyIsDown(Key.D)) {
			ship.dx = 0;
			ship.dy = 0;
			ship.dz = 0;
		}
		if(keyIsDown(Key.F) || joy.buttonWasJustPressed(Button.l3)) {
			ship.drx = 0;
			ship.dry = 0;
			ship.drz = 0;
		}
		if(keyIsDown(Key.G)) {
			ship.rx = 0;
			ship.ry = 0;
			ship.rz = 0;
		}
		if(keyIsDown(Key.I)) {
			ship.rx = 180;
		}
		if(keyIsDown(Key.O)) {
			ship.rx = 0;
		}

		version(rotate_3d) {
			axis = joy.axisPosition(Axis.verticalDpad, digitalThrust);
			if(!axis) {
				if(keyIsDown(Key.Up))
					ship.thrustUp(digitalThrust);
				if(keyIsDown(Key.Down))
					ship.thrustDown(digitalThrust);
			} else {
				if(axis < 0)
					ship.thrustUp(-axis);
				else
					ship.thrustDown(axis);
			}
		} else {
			if(keyIsDown(Key.Up) || joy.axisPosition(Axis.verticalDpad) < 0)
				ship.thrustForward();
		}
		if(keyIsDown(Key.Enter) || joy.buttonIsPressed(Button.r2))
			ship.thrustForward();
		if(keyIsDown(Key.Backspace) || joy.buttonIsPressed(Button.l2))
			ship.thrustBackward();
		if(keyIsDown(Key.Space) || joy.buttonWasJustPressed(Button.circle)) {
			ship.fire();
			import std.stdio;
			writeln(ship.x, " ", ship.y, " ", ship.z, " @ ", ship.dx, " ", ship.dy, " ", ship.dz);
		}

		window.redrawOpenGlSceneNow();
	};

	auto keyEvent = delegate (KeyEvent ke) {
		keyboardState[ke.key] = ke.pressed;
	};

	version(Windows)
	window.eventLoop(50,
		timerEvent,
		keyEvent
	);
	else version(linux) {
		import arsd.eventloop;
		window.handleKeyEvent = keyEvent;
		auto timer = setInterval(timerEvent, 50);
		flushGui();
		loop();
	}

	closeJoysticks();
}

