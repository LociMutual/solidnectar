import * as React from 'react';
import ProTip from '../src/ProTip';
import Link from '../src/Link';
import Copyright from '../src/Copyright';
import { AppBar, Box, Container, Typography } from '@mui/material';

export default function Index() {
  return (
    <Container maxWidth="sm">
      <AppBar>
        <Box sx={{ my: 4 }}>
          <Typography variant="h4" component="h1" gutterBottom>
            Next.js example
          </Typography>
          <Link href="/about" color="secondary">
            Go to the about page
          </Link>
          <ProTip />
          <Copyright />
        </Box>
      </AppBar>
    </Container>
  );
}
